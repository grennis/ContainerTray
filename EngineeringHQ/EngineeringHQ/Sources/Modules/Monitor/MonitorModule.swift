import SwiftUI

/// Runs the public endpoint checks against each ChetBackend environment on
/// demand and keeps the latest results per environment.
@MainActor
final class MonitorModule: ObservableObject, HQModule {
    let id = "monitor"
    let title = "Monitor"
    let systemImage = "stethoscope"

    enum RunStatus {
        case unknown
        case running
        case passed
        case failed
    }

    struct EnvironmentState {
        var status: RunStatus = .unknown
        var results: [String: CheckResult] = [:]
    }

    let environments = MonitorEnvironment.all
    let checks = EndpointCheck.all

    @Published private(set) var states: [String: EnvironmentState] = [:]
    @Published var selectedEnvironmentID: String?

    private let runner = CheckRunner()

    init() {
        selectedEnvironmentID = environments.first?.id
    }

    var health: ModuleHealth {
        let statuses = environments.map { state(for: $0).status }
        if statuses.contains(.failed) { return .failing }
        if statuses.contains(.passed) { return .ok }
        return .idle
    }

    func makeDetailView() -> AnyView {
        AnyView(MonitorView(module: self))
    }

    func makeMenuContent() -> AnyView {
        AnyView(MonitorMenuContent(module: self))
    }

    var selectedEnvironment: MonitorEnvironment? {
        environments.first { $0.id == selectedEnvironmentID }
    }

    func state(for environment: MonitorEnvironment) -> EnvironmentState {
        states[environment.id] ?? EnvironmentState()
    }

    /// One-line summary such as "9/11 passed · 812 ms total", or the base URL
    /// before the first run.
    func summary(for environment: MonitorEnvironment) -> String {
        let state = state(for: environment)
        guard !state.results.isEmpty else { return environment.baseURL.absoluteString }
        let results = Array(state.results.values)
        let passed = results.filter(\.ok).count
        let elapsed = results.reduce(0) { $0 + $1.elapsedMs }
        let label = state.status == .running
            ? "Running… \(results.count)/\(checks.count)"
            : "\(passed)/\(checks.count) passed"
        return "\(label) · \(elapsed) ms total"
    }

    /// Runs every check sequentially, publishing each result as it arrives.
    func run(_ environment: MonitorEnvironment) async {
        guard state(for: environment).status != .running else { return }
        states[environment.id] = EnvironmentState(status: .running)

        for check in checks {
            let result = await runner.run(check, baseURL: environment.baseURL)
            states[environment.id, default: EnvironmentState()].results[check.name] = result
        }

        let allPassed = states[environment.id]?.results.values.allSatisfy(\.ok) ?? false
        states[environment.id]?.status = allPassed ? .passed : .failed
    }

    func runSelected() async {
        guard let environment = selectedEnvironment else { return }
        await run(environment)
    }
}
