import Foundation

/// In-memory ad cache TTL aligned with `sdk/spec/video-lifecycle-v1.md`.
enum DKMadsAdCachePolicy {
    static let fullscreenMaxAge: TimeInterval = 4 * 3600
    static let inlineMaxAge: TimeInterval = 3600

    static func maxAge(for format: AdFormat) -> TimeInterval {
        switch format {
        case .banner, .native:
            return inlineMaxAge
        case .interstitial, .rewarded, .splash, .video, .audio:
            return fullscreenMaxAge
        }
    }

    static func isExpired(loadedAt: Date?, format: AdFormat, now: Date = Date()) -> Bool {
        guard let loadedAt else { return true }
        return now.timeIntervalSince(loadedAt) > maxAge(for: format)
    }
}
