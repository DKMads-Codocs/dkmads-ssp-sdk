import Foundation
import UIKit

public struct DeviceInfo {
    let type: String
    let os: String
    let osVersion: String
    let model: String
    let screenWidth: Int
    let screenHeight: Int

    func toDictionary() -> [String: Any] {
        [
            "type": type,
            "os": os,
            "osVersion": osVersion,
            "model": model,
            "screenWidth": screenWidth,
            "screenHeight": screenHeight,
        ]
    }
}

public struct AdUnit {
    public let code: String
    public let format: AdFormat
    public let sizes: [CGSize]
    public var loaded: Bool = false
}

public struct AdRequest {
    let adUnitId: String
    let format: AdFormat
    let sizes: [CGSize]
    let placementCode: String?
    let placementContext: String?
    let keyValues: [String: Any]
    let userData: UserData
    let targetingSignals: TargetingSignals
    let device: DeviceInfo
    let consent: ConsentData
    let debug: Bool

    func toDictionary() -> [String: Any] {
        var signals = targetingSignals.toSignalsDictionary()
        for (k, v) in userData { signals[k] = v }
        signals["tcf_string"] = consent.consentString ?? ""
        signals["gpp_string"] = consent.gppString ?? ""
        signals["gpp_sid"] = consent.gppSid ?? ""
        signals["gdpr"] = consent.gdpr
        signals["us_privacy"] = consent.ccpa ? "1YYY" : "1---"
        if let platformUid = PlatformIdentity.get(), !platformUid.isEmpty {
            signals["platform_uid"] = platformUid
        }
        if let idfa = AdvertisingIdentifiers.idfa(), !idfa.isEmpty {
            signals["idfa"] = idfa
        }
        var req: [String: Any] = [
            "id": UUID().uuidString,
            "format": format.apiValue,
            "device": device.toDictionary(),
            "device_type": device.type,
            "os": device.os.lowercased(),
        ]
        if let geo = targetingSignals.geoCountry, !geo.isEmpty { req["geo_country"] = geo }
        if let conn = targetingSignals.connectionType, !conn.isEmpty { req["connection_type"] = conn }
        if let cat = targetingSignals.contentCategory, !cat.isEmpty { req["content_category"] = cat }
        if let page = targetingSignals.pageType, !page.isEmpty { req["page_type"] = page }
        if !sizes.isEmpty {
            req["sizes"] = sizes.map { "\(Int($0.width))x\(Int($0.height))" }
            req["w"] = Int(sizes[0].width)
            req["h"] = Int(sizes[0].height)
        }
        return [
            "ad_unit_id": adUnitId,
            "placement_code": placementCode as Any,
            "placement_context": placementContext as Any,
            "key_values": keyValues,
            "request": req,
            "signals": signals,
            "debug": debug,
        ]
    }
}

public final class DeviceDetector {
    public static func getDeviceInfo() -> DeviceInfo {
        let screen = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let device = UIDevice.current
        let type: String
        switch device.userInterfaceIdiom {
        case .phone: type = "mobile"
        case .pad: type = "tablet"
        default: type = "mobile"
        }
        return DeviceInfo(
            type: type,
            os: "iOS",
            osVersion: device.systemVersion,
            model: device.model,
            screenWidth: Int(screen.width * scale),
            screenHeight: Int(screen.height * scale)
        )
    }
}
