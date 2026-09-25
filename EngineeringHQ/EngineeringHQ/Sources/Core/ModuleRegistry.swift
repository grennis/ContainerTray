import Combine
import Foundation

/// Holds every module and republishes their changes, so views that depend on
/// the aggregate (sidebar badges, the menu bar icon) redraw when any module
/// changes.
@MainActor
final class ModuleRegistry: ObservableObject {
    let modules: [any HQModule]
    private var cancellables: [AnyCancellable] = []

    /// The modules shown in the app, in sidebar order. Register new modules here.
    static func makeDefault() -> ModuleRegistry {
        ModuleRegistry(modules: [
            ContainersModule(),
            MonitorModule(),
        ])
    }

    init(modules: [any HQModule]) {
        self.modules = modules
        for module in modules {
            module.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    func module(id: String?) -> (any HQModule)? {
        guard let id else { return nil }
        return modules.first { $0.id == id }
    }

    var overallHealth: ModuleHealth {
        modules.map { $0.health }.max() ?? .idle
    }
}
