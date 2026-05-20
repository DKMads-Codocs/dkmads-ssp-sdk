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
        fun from(ad: Ad): DKMadsResponseInfo = DKMadsResponseInfo(
            reason = ad.reason,
            requestId = ad.requestId,
            dsp = ad.dsp,
            price = ad.price,
            loaded = ad.hasFill,
        )
    }
}
