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
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    func start(id: String) async throws {
        _ = try await run(["start", id])
    }

    func stop(id: String) async throws {
        _ = try await run(["stop", id])
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
