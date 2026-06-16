package com.dkmads.ssp

import java.util.Date

data class DKMadsBidDiagnostics(
    val adUnitId: String?,
    val format: String?,
    val reason: String?,
    val requestId: String?,
    val dsp: String?,
    val price: Double?,
    val latencyMs: Int?,
    val refreshIntervalSec: Int?,
    val loaded: Boolean,
    val errorMessage: String? = null,
    val recordedAt: Date = Date(),
) {
    val summaryText: String
        get() = buildString {
            appendLine("DKMads Ad Inspector")
            appendLine("SDK $SDK_VERSION")
            appendLine("recorded: $recordedAt")
            appendLine("---")
            adUnitId?.takeIf { it.isNotBlank() }?.let { appendLine("ad_unit_id: $it") }
            format?.takeIf { it.isNotBlank() }?.let { appendLine("format: $it") }
            appendLine("loaded: $loaded")
            reason?.let { appendLine("reason: $it") }
            requestId?.let { appendLine("request_id: $it") }
            dsp?.let { appendLine("dsp: $it") }
            price?.let { appendLine("price: $it") }
            latencyMs?.let { appendLine("latency_ms: $it") }
            refreshIntervalSec?.let { appendLine("refresh_interval_sec: $it") }
            errorMessage?.takeIf { it.isNotBlank() }?.let { appendLine("error: $it") }
        }

    val troubleshootingHint: String
        get() = DKMadsBidDiagnostics.hint(reason, loaded, format)

    companion object {
        fun hint(reason: String?, loaded: Boolean, format: String? = null): String {
            if (loaded) {
                val video = format?.lowercase() in setOf("video", "rewarded")
                return if (video) {
                    "Video fill OK — playable video_url or video adm detected."
                } else {
                    "Fill OK — render winner.adm or image_url/video_url in your view."
                }
            }
            return when ((reason ?: "").lowercase()) {
                "no_tiers" -> "Fix: Save property waterfall in dashboard (Demand → Waterfall)."
                "no_bids", "no_fill" -> "Fix: Active campaign + creative matching format/size; check floor price."
                "consent_required", "consent_blocked" -> "Fix: Set consent / CMP before load; check canRequestAds()."
                "rate_limited" -> "Fix: Reduce request frequency or increase refresh interval (≥30s)."
                else -> "Fix: curl bid with debug:true using your integration key and ad unit UUID."
            }
        }
    }
}
