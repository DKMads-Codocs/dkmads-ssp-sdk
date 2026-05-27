import AdSupport
import AppTrackingTransparency
import Foundation

enum AdvertisingIdentifiers {
    /// ATT authorization encoded for OpenRTB (0–3).
    static func attStatus() -> Int? {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .notDetermined: return 0
            case .restricted: return 1
            case .denied: return 2
            case .authorized: return 3
            @unknown default: return nil
            }
        }
        return 3
    }

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
