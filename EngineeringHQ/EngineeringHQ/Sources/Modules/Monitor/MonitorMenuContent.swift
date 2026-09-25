import SwiftUI

/// The Monitor module's items in the menu bar menu. Clicking an environment
/// runs its checks; open the main window for per-call details.
struct MonitorMenuContent: View {
    @ObservedObject var module: MonitorModule

    var body: some View {
        Section("Monitor") {
            ForEach(module.environments) { environment in
                let status = module.state(for: environment).status
                Button {
                    Task { await module.run(environment) }
                } label: {
                    Label {
                        Text(label(for: environment, status: status))
                    } icon: {
                        icon(for: status)
                    }
                }
                .disabled(status == .running)
            }
        }
    }

    private func label(for environment: MonitorEnvironment, status: MonitorModule.RunStatus) -> String {
        switch status {
        case .unknown:
            return environment.name
        case .running, .passed, .failed:
            return "\(environment.name) — \(module.summary(for: environment))"
        }
    }

    // Menu item images render as templates unless built as colored
    // non-template images, so status colors go through StatusIcon.
    private func icon(for status: MonitorModule.RunStatus) -> Image {
        switch status {
        case .unknown:
            return StatusIcon.colored("questionmark.circle.fill", color: .systemGray, accessibilityDescription: "Not run")
        case .running:
            return StatusIcon.colored("clock.fill", color: .systemBlue, accessibilityDescription: "Running")
        case .passed:
            return StatusIcon.colored("checkmark.circle.fill", color: .systemGreen, accessibilityDescription: "Passed")
        case .failed:
            return StatusIcon.colored("exclamationmark.circle.fill", color: .systemRed, accessibilityDescription: "Failed")
        }
    }
}
