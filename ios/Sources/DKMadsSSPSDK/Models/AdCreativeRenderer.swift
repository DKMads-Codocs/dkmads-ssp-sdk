import Foundation

/// How the SDK should render a winning creative.
@objc public enum DKMadsCreativeRenderer: Int {
    case nativeMP4 = 0
    case webMarkup = 1
}

enum AdMediaParsing {
    static func isHtml5AssetUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty { return false }
        return u.contains("/html5/") || u.hasSuffix(".html") || u.hasSuffix(".htm")
    }

    static func isVideoStreamUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty || isHtml5AssetUrl(u) { return false }
        return u.contains(".mp4") || u.contains(".m3u8") || u.contains(".webm")
            || u.contains(".mov") || u.contains(".m4v")
    }

    /// SSP-hosted creative files may omit a file extension in the public URL path.
    static func isHostedCreativeVideoUrl(_ url: String, isVideoCreative: Bool = true) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty || isHtml5AssetUrl(u) { return false }
        if isVideoStreamUrl(u) { return true }
        guard isVideoCreative else { return false }
        return u.contains("/api/public/creative-assets/") && u.contains("/creatives/")
    }

    static func isRasterImageUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty || isHtml5AssetUrl(u) { return false }
        let raster = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif", ".bmp", ".svg"]
        return raster.contains { u.contains($0) }
    }

    /// SSP-hosted image creatives may omit a file extension in the public URL path.
    static func isHostedCreativeImageUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty || isHtml5AssetUrl(u) { return false }
        if isRasterImageUrl(u) { return true }
        return u.contains("/api/public/creative-assets/") && u.contains("/creatives/")
    }

    static func firstHtmlAttr(in html: String, name: String) -> String? {
        let pattern = name + #"\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[capture])
    }

    static func videoSrcFromAdm(_ adm: String?, isVideoCreative: Bool = true) -> String? {
        guard let adm, !adm.isEmpty else { return nil }
        let lower = adm.lowercased()
        guard lower.contains("<video") else { return nil }
        if let src = firstHtmlAttr(in: adm, name: "src"),
           isHostedCreativeVideoUrl(src, isVideoCreative: isVideoCreative) {
            return src
        }
        if let src = firstHtmlAttr(in: adm, name: "source"),
           isHostedCreativeVideoUrl(src, isVideoCreative: isVideoCreative) {
            return src
        }
        return nil
    }
}
