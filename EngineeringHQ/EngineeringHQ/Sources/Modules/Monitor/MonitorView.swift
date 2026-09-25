import SwiftUI

/// The Monitor module's pane: environments on the left, the selected
/// environment's calls on the right.
struct MonitorView: View {
    @ObservedObject var module: MonitorModule

    var body: some View {
        HStack(spacing: 0) {
            environmentList
                .frame(width: 200)
            Divider()
            results
        }
        .navigationTitle(module.selectedEnvironment?.name ?? "Monitor")
        .navigationSubtitle(module.selectedEnvironment.map { module.summary(for: $0) } ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await module.runSelected() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
                .help("Run checks for the selected environment (⌘R)")
                .disabled(isSelectedRunning || module.selectedEnvironment == nil)
            }
        }
    }

    private var isSelectedRunning: Bool {
        guard let environment = module.selectedEnvironment else { return false }
        return module.state(for: environment).status == .running
    }

    private var environmentList: some View {
        List(selection: $module.selectedEnvironmentID) {
            Section("Environments") {
                ForEach(module.environments) { environment in
                    Label {
                        Text(environment.name)
                    } icon: {
                        MonitorStatusSymbol(status: module.state(for: environment).status)
                    }
                    .tag(environment.id)
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Run") { run(ids) }
        } primaryAction: { ids in
            // Double-click runs the environment.
            run(ids)
        }
    }

    private func run(_ ids: Set<String>) {
        for environment in module.environments where ids.contains(environment.id) {
            Task { await module.run(environment) }
        }
    }

    @ViewBuilder
    private var results: some View {
        if let environment = module.selectedEnvironment {
            let state = module.state(for: environment)
            List(module.checks) { check in
                CheckRow(
                    check: check,
                    environment: environment,
                    result: state.results[check.name],
                    isRunning: state.status == .running
                )
            }
        } else {
            Text("Select an environment, then press Run to exercise its public endpoints.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Environment status: question mark before a run, spinner while running,
/// check mark when every call passed, exclamation mark on any failure.
struct MonitorStatusSymbol: View {
    let status: MonitorModule.RunStatus

    var body: some View {
        switch status {
        case .unknown:
            Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .passed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }
}

/// One call: status icon, name and URL, HTTP status, time, and details. The
/// result is nil until the call has run.
private struct CheckRow: View {
    let check: EndpointCheck
    let environment: MonitorEnvironment
    let result: CheckResult?
    let isRunning: Bool

    private static let snippetLength = 400

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .fontWeight(.medium)
                Text("\(check.method) \((result?.url ?? check.url(relativeTo: environment.baseURL)).absoluteString)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(width: 280, alignment: .leading)

            statusCode
                .frame(width: 44, alignment: .leading)

            Text(result.map { "\($0.elapsedMs) ms" } ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)

            details
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let result {
            Image(systemName: result.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(result.ok ? Color.green : Color.red)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusCode: some View {
        if let status = result?.status {
            Text(String(status))
                .monospacedDigit()
                .foregroundStyle(status < 400 ? Color.green : Color.red)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let result {
                if let error = result.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else {
                    Text(result.contentType.isEmpty ? "no content type" : result.contentType)
                        .foregroundStyle(.secondary)
                }
                if !result.bodyPreview.isEmpty {
                    Text(snippet(result.bodyPreview))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(6)
                        .textSelection(.enabled)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                }
            } else {
                Text(isRunning ? "Waiting…" : "Not run yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func snippet(_ text: String) -> String {
        text.count > Self.snippetLength ? String(text.prefix(Self.snippetLength)) + "…" : text
    }
}
