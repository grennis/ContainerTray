import SwiftUI
import AppKit

struct ContainerMenuView: View {
    @EnvironmentObject private var manager: ContainerManager

    var body: some View {
        Section("Containers") {
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
                        Label {
                            Text(container.id)
                        } icon: {
                            containerIcon(isRunning: container.isRunning)
                        }
                    }
                    .disabled(manager.pendingContainerIDs.contains(container.id))
                }
            }
        }

        if !manager.machines.isEmpty {
            Divider()
            Text("Machines")
            ForEach(manager.machines) { machine in
                Button {
                    manager.runMachine(machine)
                } label: {
                    Label {
                        Text(machine.id)
                    } icon: {
                        machineIcon
                    }
                }
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

    // Menu item images render at whatever tint the symbol carries, but the
    // machine icon should stay white regardless of run state, so it's built
    // as a non-template NSImage rather than a plain SF Symbol Image.
    private var machineIcon: Image {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [.white])
        let nsImage = NSImage(systemSymbolName: "cube.fill", accessibilityDescription: "Container machine")?
            .withSymbolConfiguration(configuration)
        nsImage?.isTemplate = false
        return Image(nsImage: nsImage ?? NSImage())
    }

    private func containerIcon(isRunning: Bool) -> Image {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [isRunning ? .systemGreen : .white])
        let nsImage = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: isRunning ? "Running" : "Stopped")?
            .withSymbolConfiguration(configuration)
        nsImage?.isTemplate = false
        return Image(nsImage: nsImage ?? NSImage())
    }
}
