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

    /** After the document loads, open any main-frame http(s) landing URL (not SDK base host). */
    fun shouldOpenLandingUri(uri: Uri?, isMainFrame: Boolean, contentReady: Boolean): Boolean {
        if (!contentReady || !isMainFrame || uri == null) return false
        val scheme = uri.scheme?.lowercase() ?: return false
        if (scheme != "http" && scheme != "https") return false
        if (uri.host.equals("ssp.dkmads.com", ignoreCase = true)) return false
        return true
    }
}
