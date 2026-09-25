import Foundation

struct CheckResult: Identifiable {
    let name: String
    let method: String
    let url: URL
    var status: Int?
    var elapsedMs = 0
    var contentType = ""
    var ok = false
    var error: String?
    var bodyPreview = ""

    var id: String { name }
}

/// Runs endpoint checks against an environment.
struct CheckRunner {
    static let requestTimeout: TimeInterval = 15
    private static let userAgent = "EngineeringHQ/1.0"
    private static let previewLength = 2000

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = CheckRunner.requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    func run(_ check: EndpointCheck, baseURL: URL) async -> CheckResult {
        let url = check.url(relativeTo: baseURL)
        var result = CheckResult(name: check.name, method: check.method, url: url)

        var request = URLRequest(url: url)
        request.httpMethod = check.method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let started = Date()
        do {
            let (data, response) = try await session.data(for: request)
            result.elapsedMs = Self.milliseconds(since: started)
            let text = String(decoding: data, as: UTF8.self)
            result.bodyPreview = String(text.prefix(Self.previewLength))

            guard let http = response as? HTTPURLResponse else {
                result.error = "not an HTTP response"
                return result
            }
            result.status = http.statusCode
            result.contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""

            guard (200..<300).contains(http.statusCode) else {
                result.error = "HTTP \(http.statusCode)"
                return result
            }

            let payload: Any
            switch check.expect {
            case .text:
                payload = text
            case .json:
                guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                    result.error = "response is not valid JSON"
                    return result
                }
                payload = json
            }

            if let validationError = check.validate(payload) {
                result.error = validationError
                return result
            }
            result.ok = true
        } catch let error as URLError where error.code == .timedOut {
            result.elapsedMs = Self.milliseconds(since: started)
            result.error = "timed out after \(Int(Self.requestTimeout * 1000)) ms"
        } catch {
            result.elapsedMs = Self.milliseconds(since: started)
            result.error = error.localizedDescription
        }
        return result
    }

    private static func milliseconds(since start: Date) -> Int {
        Int((Date().timeIntervalSince(start) * 1000).rounded())
    }
}
