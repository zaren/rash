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
                let (output, code) = Self.runSSH(
                    host: host,
                    username: username,
                    privateKey: privateKey,
                    command: command,
                    timeout: timeout
                )
                let status: ResultStatus
                switch code {
                case 0:     status = .success
                case 255:   status = .timeout
                default:    status = .failure(code)
                }
                DispatchQueue.main.async {
                    self?.results[index].output = output
                    self?.results[index].status = status
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
                                timeout: Int) -> (String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        // Flags identical to rash.sh / rash_single.sh
        process.arguments = [
            "-i", privateKey,
            "-o", "ConnectTimeout=\(timeout)",
            "-o", "StrictHostKeyChecking=no",
            "-o", "PasswordAuthentication=no",
            "-o", "LogLevel=ERROR",
            "-q", "-T",
            "\(username)@\(host)",
            "sudo \(command)"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (error.localizedDescription, 1)
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (output, process.terminationStatus)
    }
}
