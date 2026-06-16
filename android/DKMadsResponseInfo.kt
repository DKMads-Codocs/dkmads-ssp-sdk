package com.dkmads.ssp

/**
 * Bid / fill diagnostics (`reason`, `request_id`, `dsp`, `price`) for UI and analytics.
 */
data class DKMadsResponseInfo(
    val reason: String?,
    val requestId: String?,
    val dsp: String?,
    val price: Double?,
    val loaded: Boolean,
) {
    val summary: String
        get() = listOfNotNull(
            "loaded=$loaded",
            reason?.let { "reason=$it" },
            requestId?.let { "request_id=$it" },
            dsp?.let { "dsp=$it" },
            price?.let { "price=$it" },
        ).joinToString(" ")

    companion object {
        fun from(ad: Ad, requestFormat: String? = null): DKMadsResponseInfo {
            val videoRequest = requestFormat?.lowercase() in VIDEO_REQUEST_FORMATS || ad.isVideoPlacement
            return DKMadsResponseInfo(
                reason = ad.reason,
                requestId = ad.requestId,
                dsp = ad.dsp,
                price = ad.price,
                loaded = if (videoRequest) ad.hasVideoRenderableContent else ad.hasFill,
            )
        }

        private val VIDEO_REQUEST_FORMATS = setOf("video", "rewarded")
    }
}
