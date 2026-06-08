package com.dkmads.ssp

import android.graphics.Color

internal object DKMadsCreativeChrome {
    /** 90% opaque black for fullscreen letterbox / interstitial chrome. */
    const val LETTERBOX_BG_CSS = "rgba(0,0,0,0.9)"

    val letterboxBgColor: Int
        get() = Color.argb(230, 0, 0, 0)
}
