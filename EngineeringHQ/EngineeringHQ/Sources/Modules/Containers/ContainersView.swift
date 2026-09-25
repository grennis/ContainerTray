import SwiftUI

/// The Containers module's pane in the main window.
struct ContainersView: View {
    @ObservedObject var module: ContainersModule

    var body: some View {
        Group {
            if module.isServiceStopped {
                servicesStopped
            } else {
                containerList
            }
        }
        .navigationTitle("Containers")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if module.isServiceStopped {
                    Button {
                        Task { await module.startServices() }
                    } label: {
                        Label("Start Services", systemImage: "power")
                    }
                    .help("Start container services")
                } else {
                    Button {
                        Task { await module.stopServices() }
                    } label: {
                        Label("Stop Services", systemImage: "power")
                    }
                    .help("Stop container services")
                }

                Button {
                    Task { await module.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .help("Refresh containers (⌘R)")
            }
        }
    }

    private var subtitle: String {
        if module.isServiceStopped { return "Services stopped" }
        let running = module.containers.filter(\.isRunning).count
        return "\(module.containers.count) containers · \(running) running"
    }

    private var servicesStopped: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Container services are stopped")
                .font(.title3)
            Button("Start Container Services") {
                Task { await module.startServices() }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var containerList: some View {
        List {
            if module.hasFailure, let error = module.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Section("Containers") {
                if module.containers.isEmpty {
                    Text(module.isLoading ? "Loading…" : "No containers")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(module.containers) { container in
                        containerRow(container)
                    }
                }
            }

            if !module.machines.isEmpty {
                Section("Machines") {
                    ForEach(module.machines) { machine in
                        machineRow(machine)
                    }
                }
            }
        }
    }

    private func containerRow(_ container: ContainerItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "cylinder.fill")
                .foregroundStyle(container.isRunning ? Color.green : Color.secondary)
                .accessibilityLabel(container.isRunning ? "Running" : "Stopped")
            VStack(alignment: .leading, spacing: 2) {
                Text(container.id)
                Text(container.imageReference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(container.state.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            if module.pendingContainerIDs.contains(container.id) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 56)
            } else {
                Button(container.isRunning ? "Stop" : "Start") {
                    Task { await module.toggle(container) }
                }
                .frame(width: 56)
            }
        }
        .padding(.vertical, 2)
    }

    private func machineRow(_ machine: ContainerMachine) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.fill")
                .foregroundStyle(machine.isRunning ? Color.green : Color.secondary)
            Text(machine.id)
            Spacer()
            Text(machine.status.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Shell") {
                module.runMachine(machine)
            }
            .help("Open Terminal and run `container machine run` in this machine")
        }
        .padding(.vertical, 2)
    }
}
