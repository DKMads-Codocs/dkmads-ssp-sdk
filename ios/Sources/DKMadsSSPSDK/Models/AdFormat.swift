import Foundation

@objc public enum AdFormat: Int, Codable {
    case banner = 0
    case interstitial = 1
    case native = 2
    case rewarded = 3
    case video = 4
    case audio = 5

    public var apiValue: String {
        switch self {
        case .banner: return "banner"
        case .interstitial: return "interstitial"
        case .native: return "native"
        case .rewarded: return "rewarded"
        case .video: return "video"
        case .audio: return "audio"
        }
    }
}
