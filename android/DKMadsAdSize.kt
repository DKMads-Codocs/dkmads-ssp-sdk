package com.dkmads.ssp

import android.content.Context
import android.util.DisplayMetrics

/** Ad size helpers (banner presets + anchored adaptive width). */
data class DKMadsAdSize(val width: Int, val height: Int) {
    companion object {
        fun banner300x250(): DKMadsAdSize = DKMadsAdSize(300, 250)
        fun banner320x50(): DKMadsAdSize = DKMadsAdSize(320, 50)
        fun interstitial320x480(): DKMadsAdSize = DKMadsAdSize(320, 480)

        /** Width in dp; height uses ~6.4:1 ratio clamped for anchored banners. */
        fun largeAnchoredAdaptive(context: Context, widthDp: Int): DKMadsAdSize {
            val w = widthDp.coerceAtLeast(50)
            val metrics: DisplayMetrics = context.resources.displayMetrics
            val shortSideDp = (minOf(metrics.widthPixels, metrics.heightPixels) / metrics.density).toInt()
            val maxH = (shortSideDp * 0.15f).toInt().coerceAtLeast(50)
            val ratioH = (w / 6.4f).toInt().coerceAtLeast(50)
            return DKMadsAdSize(w, minOf(ratioH, maxH))
        }
    }
}
