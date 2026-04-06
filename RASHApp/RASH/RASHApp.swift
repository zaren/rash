import SwiftUI

@main
struct RASHApp: App {

    @StateObject private var groupStore = GroupStore()

    var body: some Scene {
        WindowGroup("RASH — Remote Apple Shell Helper") {
            ContentView()
                .environmentObject(groupStore)
                .frame(minWidth: 820, minHeight: 560)
        }
        .commands {
            // Remove the default New Window shortcut (single-window tool)
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .appInfo) {
                Button("Reload Groups") {
                    groupStore.load()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
