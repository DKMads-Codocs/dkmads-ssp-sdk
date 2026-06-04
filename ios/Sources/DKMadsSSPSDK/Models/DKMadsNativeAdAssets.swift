import Foundation

/// Parsed native creative fields for custom in-feed layouts (from bid `meta` or root keys).
@objc(DKMadsNativeAdAssets)
public final class DKMadsNativeAdAssets: NSObject {
    @objc public let headline: String?
    @objc public let body: String?
    @objc public let callToAction: String?
    @objc public let advertiser: String?
    @objc public let iconUrl: String?
    @objc public let imageUrl: String?
    @objc public let clickUrl: String?

    @objc public init(
        headline: String? = nil,
        body: String? = nil,
        callToAction: String? = nil,
        advertiser: String? = nil,
        iconUrl: String? = nil,
        imageUrl: String? = nil,
        clickUrl: String? = nil
    ) {
        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.iconUrl = iconUrl
        self.imageUrl = imageUrl
        self.clickUrl = clickUrl
    }

    @objc public static func from(ad: Ad) -> DKMadsNativeAdAssets {
        ad.nativeAssets
    }

    static func from(dictionary: [String: Any]?) -> DKMadsNativeAdAssets {
        let root = dictionary ?? [:]
        let meta = root["meta"] as? [String: Any] ?? [:]
        func str(_ keys: [String]) -> String? {
            for key in keys {
                let v = (root[key] as? String) ?? (meta[key] as? String)
                let t = v?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !t.isEmpty { return t }
            }
            return nil
        }
        return DKMadsNativeAdAssets(
            headline: str(["headline", "native_title", "title"]),
            body: str(["body", "native_body", "description"]),
            callToAction: str(["cta_label", "call_to_action", "native_cta"]),
            advertiser: str(["advertiser", "sponsored_by", "brand"]),
            iconUrl: str(["icon_url", "native_icon_url"]),
            imageUrl: str(["image_url", "native_image_url", "creativeUrl", "creative_url"]) ?? (root["creativeUrl"] as? String),
            clickUrl: str(["click_url", "clickUrl"])
        )
    }
}
