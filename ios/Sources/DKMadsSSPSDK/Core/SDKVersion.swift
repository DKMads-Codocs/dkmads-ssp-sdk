import Foundation

public let SDK_VERSION = "0.5.30"

public enum SDKError: Error, LocalizedError {
    case notInitialized
    case invalidConfig
    case networkError
    case noFill
    case consentRequired
    case adExpired

    public var errorDescription: String? {
        switch self {
        case .notInitialized: return "Call DKMadsMobileAds.shared.start(...) before loading ads."
        case .invalidConfig: return "Invalid SDK configuration."
        case .networkError: return "Network request failed."
        case .noFill: return "No ad fill for this request."
        case .consentRequired: return "Consent required before requesting ads."
        case .adExpired: return "Loaded ad expired. Call load again before show."
        }
    }
}
