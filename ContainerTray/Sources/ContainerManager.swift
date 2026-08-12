import Foundation

@MainActor
final class ContainerManager: ObservableObject {
    @Published private(set) var containers: [ContainerItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var pendingContainerIDs: Set<String> = []

    private let cli = ContainerCLI()

    var hasRunningContainer: Bool {
        containers.contains { $0.isRunning }
    }

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        do {
            containers = try await cli.listContainers()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
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
}
