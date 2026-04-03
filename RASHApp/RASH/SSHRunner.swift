import Foundation

/// Executes SSH commands across a group of machines in parallel background
/// threads, using the same flags as the original Bash scripts.
class SSHRunner: ObservableObject {

    @Published var results: [MachineResult] = []
    @Published var isRunning = false

    private let sshTimeout = 15

    // MARK: - Public API

    func run(command: String,
             group: MachineGroup,
             privateKey: String,
             username: String) {
        guard !isRunning else { return }

        isRunning = true
        results = group.hosts.map {
            MachineResult(machine: $0, output: "", status: .running)
        }

        let completion = DispatchGroup()

        for (index, host) in group.hosts.enumerated() {
            completion.enter()
            let timeout = sshTimeout
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                // Reverse DNS lookup runs on the same background thread;
                // local LAN lookups are typically sub-millisecond.
                let resolvedName = Host(address: host).names.first

                let (stdout, stderr, code) = Self.runSSH(
                    host: host,
                    username: username,
                    privateKey: privateKey,
                    command: command,
                    timeout: timeout
                )
                let status: ResultStatus
                switch code {
                case 0:
                    status = .success
                case 255:
                    if stderr.lowercased().contains("permission denied") {
                        status = .authFailure
                    } else {
                        status = .timeout
                    }
                default:
                    status = .failure(code)
                }
                // Show stderr when stdout is empty so auth-failure details
                // (e.g. "Permission denied (publickey)") appear in the output.
                let displayOutput = stdout.isEmpty ? stderr : stdout
                DispatchQueue.main.async {
                    self?.results[index].output = displayOutput
                    self?.results[index].status = status
                    self?.results[index].resolvedName = resolvedName
                    completion.leave()
                }
            }
        }

        completion.notify(queue: .main) { [weak self] in
            self?.isRunning = false
        }
    }

    // MARK: - SSH execution (blocking, must run off main thread)

    private static func runSSH(host: String,
                                username: String,
                                privateKey: String,
                                command: String,
                                timeout: Int) -> (stdout: String, stderr: String, code: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        // Flags identical to rash.sh / rash_single.sh
        process.arguments = [
            "-i", privateKey,
            "-o", "ConnectTimeout=\(timeout)",
            "-o", "StrictHostKeyChecking=no",
            "-o", "PasswordAuthentication=no",
            "-o", "LogLevel=ERROR",
            "-T",
            "\(username)@\(host)",
            "sudo \(command)"
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ("", error.localizedDescription, 1)
        }

        process.waitUntilExit()

        let stdout = String(
            data: outPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let stderr = String(
            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }
}
