import Foundation
import Combine

/// Loads and persists the machine_groups.txt file, exposing its contents
/// as an array of `MachineGroup` values.
class GroupStore: ObservableObject {

    @Published var groups: [MachineGroup] = []

    static let defaultFilePath =
        NSHomeDirectory() + "/.rash/machine_groups.txt"

    /// Persisted file path; reads/writes UserDefaults automatically.
    var filePath: String {
        get {
            UserDefaults.standard.string(forKey: "groupsFilePath")
                ?? Self.defaultFilePath
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
            return
        }
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
