package com.dkmads.ssp

/** Mirrors iOS `AdMediaParsing` — hosted creatives, HLS, VAST, and adm video extraction. */
internal object AdMediaParsing {
    fun isHtml5AssetUrl(url: String): Boolean {
        val u = url.trim().lowercase()
        if (u.isEmpty()) return false
        return u.contains("/html5/") || u.endsWith(".html") || u.endsWith(".htm")
    }

    fun isRasterImageUrl(url: String): Boolean {
        val u = url.trim().lowercase()
        if (u.isEmpty() || isHtml5AssetUrl(u)) return false
        return u.contains(".jpg")
            || u.contains(".jpeg")
            || u.contains(".png")
            || u.contains(".gif")
            || u.contains(".webp")
            || u.contains(".avif")
            || u.contains(".bmp")
            || u.contains(".svg")
    }

    fun isVideoStreamUrl(url: String): Boolean {
        val u = url.trim().lowercase()
        if (u.isEmpty() || isHtml5AssetUrl(u)) return false
        return u.contains(".mp4")
            || u.contains(".m3u8")
            || u.contains(".webm")
            || u.contains(".mov")
            || u.contains(".m4v")
            || u.contains("/hls/")
    }

    /** MP4/HLS or SSP-hosted creative paths (including extensionless renditions). */
    fun isPlayableVideoUrl(url: String): Boolean {
        val u = url.trim()
        if (u.isEmpty() || isHtml5AssetUrl(u) || isRasterImageUrl(u)) return false
        if (isVideoStreamUrl(u)) return true
        val lower = u.lowercase()
        return lower.contains("/api/public/creative-assets/") && lower.contains("/creatives/")
    }

    fun isHostedCreativeVideoUrl(url: String, isVideoCreative: Boolean = true): Boolean {
        if (isPlayableVideoUrl(url)) return true
        if (!isVideoCreative) return false
        val lower = url.trim().lowercase()
        return lower.contains("/api/public/creative-assets/") && lower.contains("/creatives/")
    }

    fun firstHtmlAttr(html: String, name: String): String? {
        val pattern = Regex("""$name\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
        return pattern.find(html)?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
    }

    fun hasVideoMarkup(adm: String?): Boolean {
        if (adm.isNullOrBlank()) return false
        val lower = adm.lowercase()
        return lower.contains("<video") || lower.contains("<mediafile")
    }

    fun vastMediaFileFromAdm(adm: String?): String? {
        if (adm.isNullOrBlank() || !adm.lowercase().contains("<mediafile")) return null
        val cdata = Regex(
            """<MediaFile[^>]*>\s*<!\[CDATA\[([^\]]+)]]>\s*</MediaFile>""",
            RegexOption.IGNORE_CASE,
        )
        cdata.find(adm)?.groupValues?.getOrNull(1)?.trim()?.takeIf { isPlayableVideoUrl(it) }?.let { return it }
        val plain = Regex(
            """<MediaFile[^>]*>\s*([^<\s][^<]*)\s*</MediaFile>""",
            RegexOption.IGNORE_CASE,
        )
        plain.find(adm)?.groupValues?.getOrNull(1)?.trim()?.takeIf { isPlayableVideoUrl(it) }?.let { return it }
        return null
    }

    fun videoSrcFromAdm(adm: String?): String? {
        if (adm.isNullOrBlank()) return null
        vastMediaFileFromAdm(adm)?.let { return it }
        if (!adm.lowercase().contains("<video")) return null
        firstHtmlAttr(adm, "src")?.let { src ->
            if (isPlayableVideoUrl(src)) return src
        }
        firstHtmlAttr(adm, "source")?.let { src ->
            if (isPlayableVideoUrl(src)) return src
        }
        return null
    }
}

enum class DKMadsCreativeRenderer {
    NATIVE_MP4,
    WEB_MARKUP,
}
