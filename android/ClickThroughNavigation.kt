package com.dkmads.ssp

/** True when a WebView navigation is the campaign click-through URL (not player chrome). */
internal object ClickThroughNavigation {
    fun matches(clickUrl: String?, navigationUrl: String?): Boolean {
        val click = clickUrl?.trim().orEmpty()
        val nav = navigationUrl?.trim().orEmpty()
        if (click.isBlank() || nav.isBlank()) return false
        if (nav == click) return true
        return nav.startsWith(click)
    }
}
