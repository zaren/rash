import Foundation

// MARK: - MachineGroup

struct MachineGroup: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hosts: [String]

    /// One-line representation written back to machine_groups.txt.
    var fileRepresentation: String {
        ([name] + hosts).joined(separator: " ")
    }
}

// MARK: - ResultStatus

enum ResultStatus {
    case running
    case success
    case timeout
    case failure(Int32)
}

// MARK: - MachineResult

struct MachineResult: Identifiable {
    let id = UUID()
    let machine: String
    var output: String
    var status: ResultStatus

    var statusLabel: String {
        switch status {
        case .running:          return "Running…"
        case .success:          return "✓  Success"
        case .timeout:          return "⚡  Timeout"
        case .failure(let c):   return "✗  Error (\(c))"
        }
    }

    var isFinished: Bool {
        if case .running = status { return false }
        return true
    }
}
