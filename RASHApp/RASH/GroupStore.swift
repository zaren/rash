import Foundation
import Combine

/// Loads and persists the machine_groups.txt file, exposing its contents
/// as an array of `MachineGroup` values.
class GroupStore: ObservableObject {

    @Published var groups: [MachineGroup] = []
    @Published var fileNotFound = false

    // MARK: - Default path resolution

    /// Resolves the default path for machine_groups.txt by searching in order:
    ///  1. The directory containing the running app bundle (so the file can sit
    ///     alongside the scripts, which is the normal usage pattern).
    ///  2. ~/.rash/machine_groups.txt (conventional per-user location).
    static func resolvedDefaultFilePath() -> String {
        let filename = "machine_groups.txt"

        // 1. Next to the app bundle (e.g. /path/to/RASH.app/../machine_groups.txt)
        let appDir = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent(filename)
            .path
        if FileManager.default.fileExists(atPath: appDir) {
            return appDir
        }

        // 2. Conventional ~/.rash/ location
        return NSHomeDirectory() + "/.rash/" + filename
    }

    /// Persisted file path; reads/writes UserDefaults automatically.
    var filePath: String {
        get {
            UserDefaults.standard.string(forKey: "groupsFilePath")
                ?? Self.resolvedDefaultFilePath()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "groupsFilePath")
            objectWillChange.send()
        }
    }

    var fileURL: URL { URL(fileURLWithPath: filePath) }

    init() { load() }

    // MARK: - Load / Save

    func load() {
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
            groups = []
            fileNotFound = true
            return
        }
        fileNotFound = false
        groups = Self.parse(raw)
    }

    func save() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        let text = groups.map(\.fileRepresentation).joined(separator: "\n") + "\n"
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Mutations

    func add(name: String, hosts: [String]) {
        groups.append(MachineGroup(name: name, hosts: hosts))
        save()
    }

    func remove(at offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Parsing

    static func parse(_ text: String) -> [MachineGroup] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line -> MachineGroup? in
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count >= 2 else { return nil }
                return MachineGroup(name: parts[0], hosts: Array(parts.dropFirst()))
            }
    }
}
