import Foundation

/// A ChetBackend deployment to check. Base URLs end in `/api/` so relative
/// check paths resolve beneath it; paths with a leading `/` resolve from the
/// site root.
struct MonitorEnvironment: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: URL

    static let all: [MonitorEnvironment] = [
        MonitorEnvironment(id: "local", name: "Local", baseURL: URL(string: "http://127.0.0.1:8080/api/")!),
        MonitorEnvironment(id: "development", name: "Development", baseURL: URL(string: "https://api.chet-api-dev.com/api/")!),
        MonitorEnvironment(id: "production", name: "Production", baseURL: URL(string: "https://api.chet-api-prod.com/api/")!),
    ]
}
