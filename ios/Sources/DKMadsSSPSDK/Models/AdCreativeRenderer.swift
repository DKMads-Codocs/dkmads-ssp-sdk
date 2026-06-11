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
            || u.contains(".mov") || u.contains(".m4v") || u.contains("/hls/")
    }

    static func isPlayableVideoUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty || isHtml5AssetUrl(u) || isRasterImageUrl(u) { return false }
        if isVideoStreamUrl(u) { return true }
        let lower = u.lowercased()
        return lower.contains("/api/public/creative-assets/") && lower.contains("/creatives/")
    }

    /// SSP-hosted creative files may omit a file extension in the public URL path.
    static func isHostedCreativeVideoUrl(_ url: String, isVideoCreative: Bool = true) -> Bool {
        if isPlayableVideoUrl(url) { return true }
        guard isVideoCreative else { return false }
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    static func hasVideoMarkup(_ adm: String?) -> Bool {
        guard let adm, !adm.isEmpty else { return false }
        let lower = adm.lowercased()
        return lower.contains("<video") || lower.contains("<mediafile")
    }

    static func vastMediaFileFromAdm(_ adm: String?) -> String? {
        guard let adm, !adm.isEmpty, adm.lowercased().contains("<mediafile") else { return nil }
        if let regex = try? NSRegularExpression(
            pattern: #"<MediaFile[^>]*>\s*<!\[CDATA\[([^\]]+)]]>\s*</MediaFile>"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(adm.startIndex..<adm.endIndex, in: adm)
            if let match = regex.firstMatch(in: adm, options: [], range: range),
               match.numberOfRanges > 1,
               let capture = Range(match.range(at: 1), in: adm) {
                let url = String(adm[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isPlayableVideoUrl(url) { return url }
            }
        }
        if let regex = try? NSRegularExpression(
            pattern: #"<MediaFile[^>]*>\s*([^<\s][^<]*)\s*</MediaFile>"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(adm.startIndex..<adm.endIndex, in: adm)
            if let match = regex.firstMatch(in: adm, options: [], range: range),
               match.numberOfRanges > 1,
               let capture = Range(match.range(at: 1), in: adm) {
                let url = String(adm[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isPlayableVideoUrl(url) { return url }
            }
        }
        return nil
    }

    static func videoSrcFromAdm(_ adm: String?, isVideoCreative: Bool = true) -> String? {
        guard let adm, !adm.isEmpty else { return nil }
        if let vast = vastMediaFileFromAdm(adm) { return vast }
        guard adm.lowercased().contains("<video") else { return nil }
        if let src = firstHtmlAttr(in: adm, name: "src"), isPlayableVideoUrl(src) {
            return src
        }
        if let src = firstHtmlAttr(in: adm, name: "source"), isPlayableVideoUrl(src) {
            return src
        }
        return nil
    }
}
