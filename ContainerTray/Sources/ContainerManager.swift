import Foundation
import os.log

@MainActor
final class ContainerManager: ObservableObject {
    @Published private(set) var containers: [ContainerItem] = []
    @Published private(set) var machines: [ContainerMachine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var pendingContainerIDs: Set<String> = []

    private let cli = ContainerCLI()
    private lazy var fsWatcher = ContainerFSWatcher { [weak self] in
        self?.handleExternalChange()
    }

    private static let logger = Logger(subsystem: "com.grennis.ContainerTray", category: "ContainerManager")

    /// Bumped on every refresh; lets an in-flight refresh detect that a
    /// newer one has since started and discard its (now stale) result
    /// instead of overwriting fresher state.
    private var refreshGeneration = 0

    /// After an FSEvents signal, `container list` isn't guaranteed to
    /// reflect settled state yet, so schedule a couple of follow-up
    /// refreshes rather than trusting a single query. A new signal cancels
    /// and reschedules these so a burst collapses into one reconciliation
    /// pass anchored to the most recent signal.
    private var reconciliationTasks: [Task<Void, Never>] = []
    private static let reconciliationDelays: [Double] = [0.75, 2.0]

    var hasRunningContainer: Bool {
        containers.contains { $0.isRunning }
    }

    init() {
        Task { await refresh() }
        fsWatcher.start()
    }

    private func handleExternalChange() {
        Task { await refresh() }

        reconciliationTasks.forEach { $0.cancel() }
        reconciliationTasks = Self.reconciliationDelays.map { delay in
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        Self.logger.debug("refresh #\(generation) start")
        do {
            async let containersTask = cli.listContainers()
            async let machinesTask = cli.listMachines()
            let newContainers = try await containersTask
            let newMachines = try await machinesTask
            guard generation == refreshGeneration else {
                Self.logger.debug("refresh #\(generation) discarded (superseded by #\(self.refreshGeneration))")
                return
            }
            containers = newContainers
            machines = newMachines
            lastError = nil
            Self.logger.debug("refresh #\(generation) done: \(newContainers.count) container(s), \(newContainers.filter(\.isRunning).count) running")
        } catch {
            if generation == refreshGeneration {
                lastError = error.localizedDescription
                Self.logger.error("refresh #\(generation) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if generation == refreshGeneration {
            isLoading = false
        }
    }

    func toggle(_ container: ContainerItem) async {
        pendingContainerIDs.insert(container.id)
        defer { pendingContainerIDs.remove(container.id) }

        do {
            if container.isRunning {
                try await cli.stop(id: container.id)
            } else {
                try await cli.start(id: container.id)
            }
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runMachine(_ machine: ContainerMachine) {
        do {
            try cli.runMachine(name: machine.id)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
