import Foundation

/// Standard error codes for all load / playback paths.
@objc public enum DKMadsAdError: Int, Error, LocalizedError {
    case notInitialized = 1
    case noFill = 2
    case invalidAdUnit = 3
    case missingVideoURL = 4
    case playbackFailed = 5
    case network = 6
    case invalidConfig = 7
    case adExpired = 8
    case consentRequired = 9

    public var errorDescription: String? {
        switch self {
        case .notInitialized: return "Call DKMadsMobileAds.shared.start(...) before loading ads."
        case .noFill: return "No ad fill for this request."
        case .invalidAdUnit: return "Invalid or missing ad unit id."
        case .missingVideoURL: return "Video fill is missing a playable URL (MP4 or HLS)."
        case .playbackFailed: return "Video playback failed."
        case .network: return "Network request failed."
        case .invalidConfig: return "Invalid SDK configuration."
        case .adExpired: return "Loaded ad expired. Call load again before show."
        case .consentRequired: return "Consent required before requesting ads."
        }
    }

    public var errorCode: Int { rawValue }

    public func nsError(userInfo extra: [String: Any] = [:]) -> NSError {
        var info = extra
        info[NSLocalizedDescriptionKey] = errorDescription
        return NSError(domain: "DKMadsSSPSDK", code: rawValue, userInfo: info)
    }

    public static func from(_ error: Error) -> DKMadsAdError {
        if let typed = error as? DKMadsAdError { return typed }
        if let sdk = error as? SDKError {
            switch sdk {
            case .notInitialized: return .notInitialized
            case .noFill: return .noFill
            case .invalidConfig: return .invalidConfig
            case .networkError: return .network
            case .consentRequired: return .consentRequired
            }
        }
        let code = (error as NSError).code
        if code == 204 { return .noFill }
        if code == 422 { return .missingVideoURL }
        return .network
    }
}
