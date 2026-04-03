import SwiftUI

struct ContentView: View {

    @EnvironmentObject var groupStore: GroupStore
    @StateObject private var runner = SSHRunner()

    @State private var selectedGroupID: UUID?
    @State private var command = ""
    @State private var showingAddGroup = false
    @State private var showingSettings = false
    @State private var newGroupName = ""
    @State private var newGroupHosts = ""

    @AppStorage("sshKeyPath") private var sshKeyPath =
        NSHomeDirectory() + "/.ssh/id_rsa"
    @AppStorage("username") private var username = ""

    private var selectedGroup: MachineGroup? {
        groupStore.groups.first { $0.id == selectedGroupID }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 150, ideal: 190, max: 260)
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddGroup) {
            addGroupSheet
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(groupStore)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(groupStore.groups, selection: $selectedGroupID) { group in
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .fontWeight(.medium)
                Text(group.hosts.count == 1
                     ? "1 host"
                     : "\(group.hosts.count) hosts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(group.id)
            .contextMenu {
                Button(role: .destructive) {
                    deleteGroup(group)
                } label: {
                    Label("Delete Group", systemImage: "trash")
                }
            }
        }
        .navigationTitle("RASH")
        .toolbar {
            ToolbarItemGroup {
                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open settings")
                Button { showingAddGroup = true } label: {
                    Label("Add Group", systemImage: "plus")
                }
                .help("Add a machine group")
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let group = selectedGroup {
            VStack(spacing: 0) {
                configBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))
                Divider()
                commandBar(group: group)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider()
                outputPane
            }
        } else {
            emptyStateView
        }
    }

    private var configBar: some View {
        HStack(spacing: 12) {
            Label("SSH Key:", systemImage: "key.fill")
                .foregroundStyle(.secondary)
                .fixedSize()
            TextField("~/.ssh/id_rsa", text: $sshKeyPath)
                .textFieldStyle(.roundedBorder)
            Label("Username:", systemImage: "person.fill")
                .foregroundStyle(.secondary)
                .fixedSize()
            TextField("admin", text: $username)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
        }
    }

    private func commandBar(group: MachineGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            TextField(
                "Command to run on \(group.name) (executed with sudo)",
                text: $command
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { runCommand(on: group) }

            if runner.isRunning {
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(width: 20)
            }

            Button {
                runCommand(on: group)
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                runner.isRunning
                || command.trimmingCharacters(in: .whitespaces).isEmpty
                || username.trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
    }

    @ViewBuilder
    private var outputPane: some View {
        if runner.results.isEmpty {
            emptyOutputView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(runner.results) { result in
                        ResultRowView(result: result)
                    }
                }
                .padding(12)
            }
        }
    }

    private var emptyOutputView: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Run a command to see output here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 54))
                .foregroundStyle(.tertiary)
            Text("No Group Selected")
                .font(.title2.weight(.semibold))
            Text("Choose a machine group from the sidebar,\nor add one with the + button.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Group Sheet

    private var addGroupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Machine Group")
                .font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 12) {
                GridRow {
                    Text("Group name:")
                        .gridColumnAlignment(.trailing)
                    TextField("e.g. North_Lab", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 260)
                }
                GridRow {
                    Text("Hosts:")
                        .gridColumnAlignment(.trailing)
                    TextField("192.168.1.2 192.168.1.3  (space-separated)",
                              text: $newGroupHosts)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismissAddGroup()
                }
                .keyboardShortcut(.cancelAction)
                Button("Add") {
                    commitAddGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newGroupName.isEmpty || newGroupHosts.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Actions

    private func runCommand(on group: MachineGroup) {
        let cmd = command.trimmingCharacters(in: .whitespaces)
        let user = username.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, !user.isEmpty else { return }
        runner.run(command: cmd, group: group,
                   privateKey: sshKeyPath, username: user)
    }

    private func deleteGroup(_ group: MachineGroup) {
        if let idx = groupStore.groups.firstIndex(where: { $0.id == group.id }) {
            groupStore.remove(at: IndexSet(integer: idx))
            if selectedGroupID == group.id { selectedGroupID = nil }
        }
    }

    private func commitAddGroup() {
        let hosts = newGroupHosts
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        groupStore.add(name: newGroupName, hosts: hosts)
        dismissAddGroup()
    }

    private func dismissAddGroup() {
        showingAddGroup = false
        newGroupName = ""
        newGroupHosts = ""
    }
}

// MARK: - ResultRowView

struct ResultRowView: View {
    let result: MachineResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(statusColor)
                Text(result.machine)
                    .fontWeight(.semibold)
                Spacer()
                Text(result.statusLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if !result.output.isEmpty {
                Text(result.output)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var iconName: String {
        switch result.status {
        case .running:  return "clock"
        case .success:  return "checkmark.circle.fill"
        case .timeout:  return "exclamationmark.triangle.fill"
        case .failure:  return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .running:  return .secondary
        case .success:  return .green
        case .timeout:  return .orange
        case .failure:  return .red
        }
    }
}
