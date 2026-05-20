import Foundation

enum PublicAPIPaths {
    private static let publicRestV1 = "/api/public/v1"

    static func normalizeBase(_ baseURL: String) -> String {
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") { normalized.removeLast() }
        if normalized.hasSuffix("/api/public") { return normalized }
        if normalized.hasSuffix("/api") { return "\(normalized)/public" }
        if normalized.hasSuffix("/v1") {
            normalized = String(normalized.dropLast(3))
            while normalized.hasSuffix("/") { normalized.removeLast() }
        }
        return normalized
    }

    static func bidURL(baseURL: String) -> String {
        publicV1URL(baseURL: baseURL, path: "bid")
    }

    static func eventsURL(baseURL: String) -> String {
        publicV1URL(baseURL: baseURL, path: "events")
    }

    static func fpdMobileURL(baseURL: String) -> String {
        publicV1URL(baseURL: baseURL, path: "fpd/mobile")
    }

    private static func publicV1URL(baseURL: String, path: String) -> String {
        let base = normalizeBase(baseURL)
        if base.hasSuffix("/api/public/v1") { return "\(base)/\(path)" }
        if base.hasSuffix("/api/public") { return "\(base)/v1/\(path)" }
        return "\(base)\(publicRestV1)/\(path)"
    }
}
