import Foundation

enum ContainerCLIError: LocalizedError {
    case notFound
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The \"container\" command isn't installed."
        case .commandFailed(let message):
            return message.isEmpty ? "The container command failed." : message
        }
    }
}

/// Thin wrapper around Apple's `container` CLI.
struct ContainerCLI {
    private static let searchPaths = [
        "/usr/local/bin/container",
        "/opt/homebrew/bin/container",
    ]

    func listContainers() async throws -> [ContainerItem] {
        let output = try await run(["list", "--all", "--format", "json"])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return []
        }
        let entries = try JSONDecoder().decode([ContainerListEntry].self, from: data)
        return entries
            .map(ContainerItem.init(entry:))
            .filter { !$0.id.localizedCaseInsensitiveContains("buildkit") }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    func start(id: String) async throws {
        _ = try await run(["start", id])
    }

    func stop(id: String) async throws {
        _ = try await run(["stop", id])
    }

    func startSystem() async throws {
        _ = try await run(["system", "start"])
    }

    func stopSystem() async throws {
        _ = try await run(["system", "stop"])
    }

    func listMachines() async throws -> [ContainerMachine] {
        let output = try await run(["machine", "list", "--format", "json"])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return []
        }
        let entries = try JSONDecoder().decode([ContainerMachineListEntry].self, from: data)
        return entries
            .map(ContainerMachine.init(entry:))
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    /// `machine run` needs a real TTY, so it's opened in Terminal.app instead
    /// of run headless. There's no separate stop action: the machine session
    /// ends when the user closes or exits that Terminal window.
    func runMachine(name: String) throws {
        guard let executablePath = Self.searchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ContainerCLIError.notFound
        }
        let shellCommand = "\(shellQuoted(executablePath)) machine run -n \(shellQuoted(name))"
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptQuoted(shellCommand))"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
    }

    private func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuoted(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    @discardableResult
    private func run(_ arguments: [String]) async throws -> String {
        guard let executablePath = Self.searchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ContainerCLIError.notFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { finished in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if finished.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: ContainerCLIError.commandFailed(message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
