import AdSupport
import AppTrackingTransparency
import Foundation

enum AdvertisingIdentifiers {
    /// IDFA when ATT authorized (iOS 14+).
    static func idfa() -> String? {
        if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else { return nil }
        }
        let uuid = ASIdentifierManager.shared().advertisingIdentifier
        let s = uuid.uuidString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s == "00000000-0000-0000-0000-000000000000" { return nil }
        return s
    }
}
