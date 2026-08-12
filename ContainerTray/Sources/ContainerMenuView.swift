import SwiftUI
import AppKit

struct ContainerMenuView: View {
    @EnvironmentObject private var manager: ContainerManager

    private static let maxTextWidth: CGFloat = 280

    var body: some View {
        if manager.isServiceStopped {
            Text("Container services stopped")
                .frame(maxWidth: Self.maxTextWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Section("Containers") {
                if manager.containers.isEmpty {
                    if manager.isLoading {
                        Text("Loading…")
                    } else if let error = manager.lastError {
                        Text("Error: \(error)")
                            .frame(maxWidth: Self.maxTextWidth, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
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
                Section("Machines") {
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
            }
        }

        Divider()

        Section {
            if manager.isServiceStopped {
                Button("Start container services") {
                    Task { await manager.startServices() }
                }
                .keyboardShortcut("s")
            } else {
                Button("Stop container services") {
                    Task { await manager.stopServices() }
                }
            }
        }

        Section {
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
