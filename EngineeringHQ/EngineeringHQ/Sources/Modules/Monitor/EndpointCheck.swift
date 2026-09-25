import Foundation

/// A read-only `GET` against a public (unauthenticated) ChetBackend endpoint.
/// `validate` receives the decoded body (a JSON value from
/// `JSONSerialization`, or a `String` when `expect` is `.text`) and returns
/// an error message, or nil when the body looks right.
struct EndpointCheck: Identifiable {
    enum Expectation {
        case json
        case text
    }

    let name: String
    let path: String
    var expect: Expectation = .json
    let validate: (Any) -> String?

    var id: String { name }
    var method: String { "GET" }

    func url(relativeTo baseURL: URL) -> URL {
        URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }
}

// MARK: - Checks

extension EndpointCheck {
    /// Only add endpoints that need no authentication and have no side
    /// effects. `GET` only, and every check validates the body's shape, not
    /// just the status code.
    static let all: [EndpointCheck] = [
        EndpointCheck(name: "Health check", path: "/", expect: .text) { body in
            let text = body as? String ?? ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
                ? nil
                : "expected \"OK\", got \"\(text.prefix(40))\""
        },
        EndpointCheck(name: "Configuration", path: "configuration") { body in
            if let error = expectKeys(body, ["minimumBundleVersion", "serverDate", "enableFacebookLogin", "enableEmailLogin"]) {
                return error
            }
            let serverDate = (body as? [String: Any])?["serverDate"]
            return isValidDate(serverDate) ? nil : "serverDate is not a valid date"
        },
        EndpointCheck(name: "Info", path: "info") { body in
            body is [String: Any] ? nil : "expected a JSON object"
        },
        EndpointCheck(name: "Feedback options", path: "feedback/options") { body in
            expectArrayField(body, "options")
        },
        EndpointCheck(name: "Leagues", path: "leagues") { body in
            expectArrayField(body, "leagues")
        },
        EndpointCheck(name: "Bot status", path: "bot/status") { body in
            if let error = expectArrayField(body, "bots") { return error }
            let bots = (body as? [String: Any])?["bots"] as? [Any] ?? []
            let bad = bots.contains { entry in
                guard let bot = entry as? [String: Any] else { return true }
                return bot["userID"] == nil || !isNumber(bot["rating"])
            }
            return bad ? "a bot entry is missing userID or a numeric rating" : nil
        },
        EndpointCheck(name: "Random question", path: "question/random?noteCount=5") { body in
            if let error = expectKeys(body, ["sequenceABC"]) { return error }
            let sequence = (body as? [String: Any])?["sequenceABC"] as? String ?? ""
            return sequence.isEmpty ? "sequenceABC is empty" : nil
        },
        EndpointCheck(name: "Music theory: standardize", path: "music-theory/standardize?sequenceABC=CDE") { body in
            expectKeys(body, ["sequenceABC"])
        },
        EndpointCheck(name: "Music theory: simplify", path: "music-theory/simplify?sequenceABC=CDE") { body in
            expectKeys(body, ["sequenceABC"])
        },
        EndpointCheck(name: "Music theory: transpose", path: "music-theory/transpose?sequenceABC=ABC&tonic=E") { body in
            expectKeys(body, ["sequenceABC"])
        },
        EndpointCheck(name: "Apple app site association", path: "/.well-known/apple-app-site-association") { body in
            body is [String: Any] ? nil : "expected a JSON object"
        },
    ]

    // MARK: Validation helpers

    private static func expectKeys(_ body: Any, _ keys: [String]) -> String? {
        guard let object = body as? [String: Any] else { return "expected a JSON object" }
        let missing = keys.filter { object[$0] == nil }
        return missing.isEmpty ? nil : "missing keys: \(missing.joined(separator: ", "))"
    }

    private static func expectArrayField(_ body: Any, _ field: String) -> String? {
        guard let object = body as? [String: Any] else { return "expected a JSON object" }
        return object[field] is [Any] ? nil : "\"\(field)\" is not an array"
    }

    /// A finite JSON number. `JSONSerialization` decodes booleans as
    /// `NSNumber` too, so those are excluded explicitly.
    private static func isNumber(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return number.doubleValue.isFinite
    }

    /// Accepts ISO 8601 (with or without fractional seconds) and RFC 1123
    /// dates, the formats `Date.parse` in the original checks accepted from
    /// this server.
    private static func isValidDate(_ value: Any?) -> Bool {
        guard let string = value as? String else { return false }
        let iso = ISO8601DateFormatter()
        if iso.date(from: string) != nil { return true }
        iso.formatOptions.insert(.withFractionalSeconds)
        if iso.date(from: string) != nil { return true }
        let rfc1123 = DateFormatter()
        rfc1123.locale = Locale(identifier: "en_US_POSIX")
        rfc1123.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return rfc1123.date(from: string) != nil
    }
}
