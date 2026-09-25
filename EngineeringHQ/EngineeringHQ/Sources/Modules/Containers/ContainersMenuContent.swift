import SwiftUI
import AppKit

/// The Containers module's items in the menu bar menu.
struct ContainersMenuContent: View {
    @ObservedObject var module: ContainersModule

    private static let maxTextWidth: CGFloat = 280

    var body: some View {
        if module.isServiceStopped {
            Text("Container services stopped")
                .frame(maxWidth: Self.maxTextWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Section("Containers") {
                if module.containers.isEmpty {
                    if module.isLoading {
                        Text("Loading…")
                    } else if let error = module.lastError {
                        Text("Error: \(error)")
                            .frame(maxWidth: Self.maxTextWidth, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No containers")
                    }
                } else {
                    ForEach(module.containers) { container in
                        Button {
                            Task { await module.toggle(container) }
                        } label: {
                            Label {
                                Text(container.id)
                            } icon: {
                                containerIcon(isRunning: container.isRunning)
                            }
                        }
                        .disabled(module.pendingContainerIDs.contains(container.id))
                    }
                }
            }

            if !module.machines.isEmpty {
                Section("Machines") {
                    ForEach(module.machines) { machine in
                        Button {
                            module.runMachine(machine)
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

        Section {
            if module.isServiceStopped {
                Button("Start container services") {
                    Task { await module.startServices() }
                }
            } else {
                Button("Stop container services") {
                    Task { await module.stopServices() }
                }
            }

            Button("Refresh containers") {
                Task { await module.refresh() }
            }
        }
    }

    // The machine icon stays white regardless of run state, so it's built
    // as a colored non-template image rather than a plain SF Symbol Image.
    private var machineIcon: Image {
        StatusIcon.colored("cube.fill", color: .white, accessibilityDescription: "Container machine")
    }

    private func containerIcon(isRunning: Bool) -> Image {
        StatusIcon.colored("cylinder.fill", color: isRunning ? .systemGreen : .white, accessibilityDescription: isRunning ? "Running" : "Stopped")
    }
}
