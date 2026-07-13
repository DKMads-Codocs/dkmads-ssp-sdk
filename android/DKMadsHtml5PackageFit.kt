package com.dkmads.ssp

/**
 * Outer scale/letterbox for hosted HTML5 packages in fullscreen (interstitial / app open).
 * Does not mutate creative DOM — sizes the WebView to package pixels, then scales to fit.
 */
object DKMadsHtml5PackageFit {
    /** Bid / IAB package size; interstitial HTML5 defaults to 320×480 when missing. */
    fun packageSize(ad: Ad, defaultWidth: Int = 320, defaultHeight: Int = 480): Pair<Int, Int> {
        val w = when {
            ad.slotW > 0 -> ad.slotW
            ad.width > 0 -> ad.width
            else -> defaultWidth
        }
        val h = when {
            ad.slotH > 0 -> ad.slotH
            ad.height > 0 -> ad.height
            else -> defaultHeight
        }
        return w.coerceAtLeast(1) to h.coerceAtLeast(1)
    }

    /** Uniform scale so [packageW]×[packageH] fits inside the container (contain / letterbox). */
    fun containScale(packageW: Float, packageH: Float, containerW: Float, containerH: Float): Float {
        if (packageW <= 0f || packageH <= 0f || containerW <= 0f || containerH <= 0f) return 1f
        return minOf(containerW / packageW, containerH / packageH)
    }
}
