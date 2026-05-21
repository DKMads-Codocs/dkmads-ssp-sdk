import Foundation

public let SDK_VERSION = "0.4.2"

public enum SDKError: Error, LocalizedError {
    case notInitialized
    case invalidConfig
    case networkError
    case noFill

    public var errorDescription: String? {
        switch self {
        case .notInitialized: return "Call DKMadsMobileAds.shared.start(...) before loading ads."
        case .invalidConfig: return "Invalid SDK configuration."
        case .networkError: return "Network request failed."
        case .noFill: return "No ad fill for this request."
        }
    }
}
