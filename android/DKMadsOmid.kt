package com.dkmads.ssp

import android.content.Context
import android.view.View
import android.webkit.WebView

/**
 * Open Measurement (OMID) verification resource, parsed from the bid winner
 * (`winner.omid_verifications` / VAST `<AdVerifications>`).
 */
data class DKMadsOmidVerification(
    val vendorKey: String,
    val javascriptResourceUrl: String,
    val verificationParameters: String? = null,
)

/**
 * Active OMID measurement session. Implemented by an OM SDK adapter; the SDK
 * core only calls these lifecycle signals at the right moments.
 */
interface DKMadsOmidSession {
    fun start()
    fun signalLoaded()
    fun signalImpression()
    fun signalVideoStart(durationSec: Float, volume: Float) {}
    fun signalVideoFirstQuartile() {}
    fun signalVideoMidpoint() {}
    fun signalVideoThirdQuartile() {}
    fun signalVideoComplete() {}
    fun signalVideoPaused() {}
    fun signalVideoResumed() {}
    fun signalVideoSkipped() {}
    fun finish()
}

/**
 * Pluggable OMID provider. Apps that integrate the IAB OM SDK register a real
 * implementation via [DKMadsOmid.provider]; otherwise OMID is a no-op and the
 * SDK falls back to first-party MRC-style viewability telemetry.
 */
interface DKMadsOmidProvider {
    val partnerName: String
    val partnerVersion: String
    val isActive: Boolean

    /** HTML/display session over a creative [webView]. */
    fun createHtmlDisplaySession(context: Context, webView: WebView): DKMadsOmidSession?

    /** Native display session over an [adView] with verification resources. */
    fun createNativeDisplaySession(
        context: Context,
        adView: View,
        verifications: List<DKMadsOmidVerification>,
    ): DKMadsOmidSession?

    /** Video session over a player [adView] with verification resources. */
    fun createVideoSession(
        context: Context,
        adView: View,
        verifications: List<DKMadsOmidVerification>,
    ): DKMadsOmidSession?
}

/** Global OMID registry. Set [provider] once at app start when the OM SDK is present. */
object DKMadsOmid {
    @JvmStatic
    var provider: DKMadsOmidProvider? = null

    @JvmStatic
    val isAvailable: Boolean
        get() = provider?.isActive == true
}
