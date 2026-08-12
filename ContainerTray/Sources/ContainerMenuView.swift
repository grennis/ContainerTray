import SwiftUI

struct ContainerMenuView: View {
    @EnvironmentObject private var manager: ContainerManager

    var body: some View {
        if manager.containers.isEmpty {
            if manager.isLoading {
                Text("Loading…")
            } else if let error = manager.lastError {
                Text("Error: \(error)")
            } else {
                Text("No containers")
            }
        } else {
            ForEach(manager.containers) { container in
                Button {
                    Task { await manager.toggle(container) }
                } label: {
                    Text("\(container.isRunning ? "🟢" : "⚪️")  \(container.id)")
                }
                .disabled(manager.pendingContainerIDs.contains(container.id))
            }
        }

        Divider()

        Button("Refresh") {
            Task { await manager.refresh() }
        }
        .keyboardShortcut("r")

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
