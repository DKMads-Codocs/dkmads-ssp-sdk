import Foundation

@objc public class Ad: NSObject {
    @objc public let id: String
    @objc public let creativeUrl: String
    @objc public let clickUrl: String
    @objc public let width: Int
    @objc public let height: Int
    @objc public let adm: String?
    @objc public let campaignId: String?
    @objc public let creativeId: String?
    @objc public let dsp: String?
    /// Set after `recordAdImpression` (avoids duplicate on `display(_:)` / interstitial).
    @objc public var impressionRecorded = false
    @objc public let html5EntryUrl: String?
    @objc public let videoUrl: String?
    @objc public let audioUrl: String?
    @objc public let deliveryType: String?
    @objc public let creativeType: String?
    @objc public let videoTemplate: String?
    @objc public let ctaLabel: String
    @objc public let ctaPosition: String?
    @objc public let companionImageUrl: String?
    @objc public let showCompanionClick: NSNumber?
    @objc public let skippable: NSNumber?
    @objc public let skipAfterSec: NSNumber?
    @objc public let unitFormat: String?
    @objc public let placementContext: String?

    private let bidPayload: [String: Any]

    public init(from dictionary: [String: Any]) {
        self.bidPayload = dictionary
        let meta = dictionary["meta"] as? [String: Any]
        self.adm = dictionary["adm"] as? String
        self.deliveryType = (dictionary["delivery_type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.creativeType = (dictionary["creative_type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.html5EntryUrl = (dictionary["html5_entry_url"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.videoUrl = (dictionary["video_url"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.audioUrl = (dictionary["audio_url"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.creativeUrl = Ad.resolveCreativeUrl(from: dictionary, meta: meta)
        var resolvedId = (dictionary["id"] as? String)
            ?? (dictionary["crid"] as? String)
            ?? (meta?["creative_id"] as? String)
            ?? ""
        if resolvedId.isEmpty, !creativeUrl.isEmpty {
            resolvedId = creativeUrl
        } else if resolvedId.isEmpty, !(adm?.isEmpty ?? true) {
            resolvedId = "html-creative"
        }
        self.id = resolvedId
        self.clickUrl = (dictionary["clickUrl"] as? String)
            ?? (dictionary["click_url"] as? String)
            ?? (meta?["click_url"] as? String)
            ?? ""
        self.width = (dictionary["width"] as? Int)
            ?? (dictionary["w"] as? Int)
            ?? Int(meta?["width"] as? String ?? "")
            ?? 0
        self.height = (dictionary["height"] as? Int)
            ?? (dictionary["h"] as? Int)
            ?? Int(meta?["height"] as? String ?? "")
            ?? 0
        let cid = (dictionary["cid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.campaignId = cid.isEmpty ? nil : cid
        let crid = (dictionary["crid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.creativeId = crid.isEmpty ? nil : crid
        let dspVal = (dictionary["dsp"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.dsp = dspVal.isEmpty ? nil : dspVal
        let tmpl = (dictionary["video_template"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.videoTemplate = tmpl.isEmpty ? nil : tmpl
        let cta = (dictionary["cta_label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ctaLabel = cta.isEmpty ? "Learn more" : cta
        let pos = (dictionary["cta_position"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ctaPosition = pos.isEmpty ? nil : pos
        let companion = (dictionary["companion_image_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.companionImageUrl = companion.isEmpty ? nil : companion
        self.showCompanionClick = dictionary["show_companion_click"] as? NSNumber
        self.skippable = dictionary["skippable"] as? NSNumber
        self.skipAfterSec = dictionary["skip_after_sec"] as? NSNumber
        let format = (dictionary["unit_format"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.unitFormat = format.isEmpty ? nil : format
        let context = (dictionary["placement_context"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.placementContext = context.isEmpty ? nil : context
    }

    @objc public var nativeAssets: DKMadsNativeAdAssets {
        DKMadsNativeAdAssets.from(dictionary: bidPayload)
    }

    @objc public var hasFill: Bool {
        if isHTML5 { return !(html5EntryUrl ?? "").isEmpty || !(adm?.isEmpty ?? true) }
        if requiresVideoFill { return hasVideoRenderableContent }
        if hasVideoRenderableContent { return true }
        if isAudio { return !(audioUrl ?? "").isEmpty || (adm?.lowercased().contains("<audio") == true) }
        if !creativeUrl.isEmpty { return true }
        if let adm, !adm.isEmpty { return true }
        return false
    }

    @objc public var isVideoPlacement: Bool {
        requiresVideoFill
    }

    private var requiresVideoFill: Bool {
        if isDisplayUnitFormat {
            return isVideoDeliveryType || hasVideoRenderableContent
        }
        return isVideoUnitFormat || isVideoDeliveryType
    }

    private var isDisplayUnitFormat: Bool {
        switch (unitFormat ?? "").lowercased() {
        case "banner", "interstitial", "native":
            return true
        default:
            return false
        }
    }

    private var isVideoDeliveryType: Bool {
        switch (deliveryType ?? creativeType ?? "").lowercased() {
        case "video", "rewarded", "splash":
            return true
        default:
            return false
        }
    }

    private var isVideoUnitFormat: Bool {
        switch (unitFormat ?? "").lowercased() {
        case "video", "video_instream", "video_outstream", "rewarded", "splash", "display_video":
            return true
        default:
            return false
        }
    }

    @objc public var hasVideoRenderableContent: Bool {
        if let url = playableVideoURL, !url.isEmpty { return true }
        return AdMediaParsing.hasVideoMarkup(adm)
    }

    @objc public var isAudio: Bool {
        if isHTML5 || isVideo { return false }
        let dt = (deliveryType ?? creativeType ?? unitFormat ?? "").lowercased()
        if dt == "audio" { return true }
        if let audioUrl, !audioUrl.isEmpty { return true }
        if let adm, adm.lowercased().contains("<audio") { return true }
        return false
    }

    @objc public var isHTML5: Bool {
        if isVideo { return false }
        if deliveryType?.lowercased() == "html5" { return true }
        if creativeType?.lowercased() == "html5" { return true }
        if let html5EntryUrl, !html5EntryUrl.isEmpty { return true }
        if let adm, !adm.isEmpty {
            let lower = adm.lowercased()
            if lower.contains("<iframe") || adm.contains("/html5/") { return true }
        }
        return false
    }

    @objc public var isVideo: Bool {
        if isVideoDeliveryType { return true }
        if let videoUrl, !videoUrl.isEmpty, AdMediaParsing.isPlayableVideoUrl(videoUrl) { return true }
        if AdMediaParsing.hasVideoMarkup(adm) { return true }
        return false
    }

    @objc public var preferredPlaybackURL: String? {
        playableVideoURL
    }

    /// Native player URL — includes hosted creative-assets paths without file extensions.
    @objc public var playableVideoURL: String? {
        if let videoUrl, !videoUrl.isEmpty, AdMediaParsing.isPlayableVideoUrl(videoUrl) {
            return videoUrl
        }
        if let fromAdm = AdMediaParsing.videoSrcFromAdm(adm) { return fromAdm }
        if let videoUrl, !videoUrl.isEmpty,
           !AdMediaParsing.isHtml5AssetUrl(videoUrl),
           !AdMediaParsing.isRasterImageUrl(videoUrl) {
            return videoUrl
        }
        return nil
    }

    public var preferredRenderer: DKMadsCreativeRenderer {
        if let url = playableVideoURL, !url.isEmpty { return .nativeMP4 }
        if isHTML5 || (adm?.lowercased().contains("<iframe") == true) { return .webMarkup }
        if let adm, !adm.isEmpty { return .webMarkup }
        return .webMarkup
    }

    private static func resolveCreativeUrl(from winner: [String: Any], meta: [String: Any]?) -> String {
        let dt = (winner["delivery_type"] as? String) ?? (winner["creative_type"] as? String) ?? ""
        if dt.lowercased() == "html5" { return "" }
        if dt.lowercased() == "video" { return "" }
        if let direct = winner["creativeUrl"] as? String, !direct.isEmpty,
           AdMediaParsing.isRasterImageUrl(direct) || AdMediaParsing.isHostedCreativeImageUrl(direct) { return direct }
        if let image = winner["image_url"] as? String, !image.isEmpty,
           AdMediaParsing.isRasterImageUrl(image) || AdMediaParsing.isHostedCreativeImageUrl(image) { return image }
        if let metaImage = meta?["image_url"] as? String, !metaImage.isEmpty,
           AdMediaParsing.isRasterImageUrl(metaImage) || AdMediaParsing.isHostedCreativeImageUrl(metaImage) { return metaImage }
        if dt.lowercased() != "video", dt.lowercased() != "rewarded", dt.lowercased() != "splash",
           let preview = winner["preview_url"] as? String, !preview.isEmpty,
           AdMediaParsing.isHostedCreativeImageUrl(preview) { return preview }
        if let adm = winner["adm"] as? String, !adm.isEmpty {
            let lower = adm.lowercased()
            if lower.contains("<iframe") || adm.contains("/html5/") { return "" }
            if lower.contains("<video") { return "" }
            if let src = AdMediaParsing.firstHtmlAttr(in: adm, name: "src"), AdMediaParsing.isRasterImageUrl(src) { return src }
        }
        return ""
    }
}
