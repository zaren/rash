import SwiftUI
import AppKit

/// Two-tab settings sheet:
///  • Connection — SSH key path + admin username
///  • Groups File — path to machine_groups.txt with inline text editor
struct SettingsView: View {

    @EnvironmentObject var groupStore: GroupStore

    @AppStorage("sshKeyPath") private var sshKeyPath =
        NSHomeDirectory() + "/.ssh/id_rsa"
    @AppStorage("username") private var username = ""

    @State private var filePathDraft = ""
    @State private var groupsTextDraft = ""
    @State private var saveStatus = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            connectionTab
                .tabItem { Label("Connection", systemImage: "network") }
            groupsTab
                .tabItem { Label("Groups File", systemImage: "doc.text") }
        }
        .padding(20)
        .frame(width: 540, height: 380)
        .onAppear {
            filePathDraft = groupStore.filePath
            reloadText()
        }
    }

    // MARK: - Connection tab

    private var connectionTab: some View {
        Form {
            Section {
                HStack {
                    TextField("Path to SSH private key", text: $sshKeyPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browseForKey() }
                }
                TextField("Admin username on remote machines", text: $username)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("SSH Configuration")
                    .fontWeight(.semibold)
            } footer: {
                Text("The key must already be installed on every managed machine.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Groups file tab

    private var groupsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("File:")
                    .foregroundStyle(.secondary)
                TextField("Path to machine_groups.txt", text: $filePathDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") { browseForGroupsFile() }
                Button("Reload") {
                    groupStore.filePath = filePathDraft
                    groupStore.load()
                    reloadText()
                }
            }

            Text("Format:  GroupName  IP1  IP2  IP3   (one group per line)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $groupsTextDraft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .border(Color.secondary.opacity(0.35), width: 1)

            HStack {
                if !saveStatus.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(saveStatus)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                Spacer()
                Button("Save") { saveGroupsText() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helpers

    private func reloadText() {
        groupsTextDraft = (try? String(contentsOf: groupStore.fileURL,
                                       encoding: .utf8)) ?? ""
    }

    private func saveGroupsText() {
        groupStore.filePath = filePathDraft
        let url = groupStore.fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? groupsTextDraft.write(to: url, atomically: true, encoding: .utf8)
        groupStore.load()
        saveStatus = "Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveStatus = ""
        }
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select SSH Private Key"
        if panel.runModal() == .OK, let url = panel.url {
            sshKeyPath = url.path
        }
    }

    private func browseForGroupsFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select machine_groups.txt"
        panel.nameFieldStringValue = "machine_groups.txt"
        if panel.runModal() == .OK, let url = panel.url {
            filePathDraft = url.path
        }
    }
}
