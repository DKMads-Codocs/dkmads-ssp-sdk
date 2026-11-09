package com.dkmads.ssp

import android.net.Uri

/** True when a WebView navigation is the campaign click-through URL (not player chrome). */
internal object ClickThroughNavigation {
    fun matches(clickUrl: String?, navigationUrl: String?): Boolean {
        val click = clickUrl?.trim().orEmpty()
        val nav = navigationUrl?.trim().orEmpty()
        if (click.isBlank() || nav.isBlank()) return false
        if (nav == click) return true
        return nav.startsWith(click)
    }

    fun isAllowedExternalScheme(uri: Uri?, clickUrl: String?): Boolean {
        if (uri == null) return false
        val scheme = uri.scheme?.lowercase() ?: return false
        if (scheme == "https") return true
        if (scheme == "http") {
            val clickScheme = clickUrl?.trim()?.takeIf { it.isNotEmpty() }
                ?.let { Uri.parse(it).scheme?.lowercase() }
            return clickScheme == "http"
        }
        return false
    }

    /**
     * After the document loads, open only declared bid click-through URLs (https preferred).
     * Blocks intent/javascript schemes and arbitrary main-frame navigations.
     */
    fun shouldOpenLandingUri(
        uri: Uri?,
        isMainFrame: Boolean,
        contentReady: Boolean,
        clickUrl: String? = null,
    ): Boolean {
        if (!contentReady || !isMainFrame || uri == null) return false
        if (!isAllowedExternalScheme(uri, clickUrl)) return false
        if (uri.host.equals("ssp.dkmads.com", ignoreCase = true)) return false
        val click = clickUrl?.trim().orEmpty()
        if (click.isBlank()) return false
        return matches(click, uri.toString())
    }

    /** Resolve an external open target for CTA / MRAID: prefer declared click_url. */
    fun resolveExternalUri(candidate: String?, clickUrl: String?): Uri? {
        val click = clickUrl?.trim().orEmpty()
        val nav = candidate?.trim().orEmpty()
        val preferred = when {
            click.isNotBlank() && nav.isNotBlank() && matches(click, nav) -> nav
            click.isNotBlank() -> click
            else -> return null
        }
        val uri = runCatching { Uri.parse(preferred) }.getOrNull() ?: return null
        if (!isAllowedExternalScheme(uri, clickUrl)) return null
        if (uri.host.equals("ssp.dkmads.com", ignoreCase = true)) return null
        return uri
    }
}
