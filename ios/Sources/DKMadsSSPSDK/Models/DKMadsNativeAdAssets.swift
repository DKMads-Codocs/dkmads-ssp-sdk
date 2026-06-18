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
    /// App/store assets (OpenRTB Native data assets): rating 0–5, price, downloads, likes.
    @objc public let rating: String?
    @objc public let price: String?
    @objc public let downloads: String?
    @objc public let likes: String?

    @objc public init(
        headline: String? = nil,
        body: String? = nil,
        callToAction: String? = nil,
        advertiser: String? = nil,
        iconUrl: String? = nil,
        imageUrl: String? = nil,
        clickUrl: String? = nil,
        rating: String? = nil,
        price: String? = nil,
        downloads: String? = nil,
        likes: String? = nil
    ) {
        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.iconUrl = iconUrl
        self.imageUrl = imageUrl
        self.clickUrl = clickUrl
        self.rating = rating
        self.price = price
        self.downloads = downloads
        self.likes = likes
    }

    @objc public static func from(ad: Ad) -> DKMadsNativeAdAssets {
        ad.nativeAssets
    }

    static func from(dictionary: [String: Any]?) -> DKMadsNativeAdAssets {
        let root = dictionary ?? [:]
        if let assets = root["native_assets"] as? [String: Any] {
            func a(_ keys: [String]) -> String? {
                for key in keys {
                    if let s = assets[key] as? String {
                        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty { return t }
                    } else if let n = assets[key] as? NSNumber {
                        return n.stringValue
                    }
                }
                return nil
            }
            return DKMadsNativeAdAssets(
                headline: a(["headline"]),
                body: a(["body", "description"]),
                callToAction: a(["cta", "cta_label"]),
                advertiser: a(["advertiser"]),
                iconUrl: a(["icon_url"]),
                imageUrl: a(["image_url"]),
                clickUrl: a(["click_url"]),
                rating: a(["rating"]),
                price: a(["price", "saleprice"]),
                downloads: a(["downloads"]),
                likes: a(["likes"])
            )
        }
        let meta = root["meta"] as? [String: Any] ?? [:]
        func str(_ keys: [String]) -> String? {
            for key in keys {
                if let s = (root[key] as? String) ?? (meta[key] as? String) {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { return t }
                } else if let n = (root[key] as? NSNumber) ?? (meta[key] as? NSNumber) {
                    return n.stringValue
                }
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
            clickUrl: str(["click_url", "clickUrl"]),
            rating: str(["rating"]),
            price: str(["price", "saleprice"]),
            downloads: str(["downloads"]),
            likes: str(["likes"])
        )
    }
}
