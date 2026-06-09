package com.dkmads.ssp

/** Mirrors iOS `AdMediaParsing` — hosted creatives, HLS, and adm video extraction. */
internal object AdMediaParsing {
    fun isHtml5AssetUrl(url: String): Boolean {
        val u = url.trim().lowercase()
        if (u.isEmpty()) return false
        return u.contains("/html5/") || u.endsWith(".html") || u.endsWith(".htm")
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

    fun isHostedCreativeVideoUrl(url: String, isVideoCreative: Boolean = true): Boolean {
        val u = url.trim().lowercase()
        if (u.isEmpty() || isHtml5AssetUrl(u)) return false
        if (isVideoStreamUrl(u)) return true
        if (!isVideoCreative) return false
        return u.contains("/api/public/creative-assets/") && u.contains("/creatives/")
    }

    fun firstHtmlAttr(html: String, name: String): String? {
        val pattern = Regex("""$name\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
        return pattern.find(html)?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
    }

    fun videoSrcFromAdm(adm: String?, isVideoCreative: Boolean = true): String? {
        if (adm.isNullOrBlank()) return null
        if (!adm.lowercase().contains("<video")) return null
        firstHtmlAttr(adm, "src")?.let { src ->
            if (isHostedCreativeVideoUrl(src, isVideoCreative)) return src
        }
        firstHtmlAttr(adm, "source")?.let { src ->
            if (isHostedCreativeVideoUrl(src, isVideoCreative)) return src
        }
        return null
    }
}

enum class DKMadsCreativeRenderer {
    NATIVE_MP4,
    WEB_MARKUP,
}
