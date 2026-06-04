package com.dkmads.ssp

import android.app.Activity
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Fullscreen interstitial (video, image, HTML5, or tag). Use when the dashboard ad unit format is `interstitial`.
 *
 * Bid sizes use explicit `adWidth`×`adHeight`, then [SSPSDK.registeredSizes], then **320×480** (not display pixels).
 */
class DKMadsInterstitialAd(
    override val adUnitId: String,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob()),
) : DKMadsFullScreenPresenting {
    interface Listener {
        fun onAdLoaded(interstitial: DKMadsInterstitialAd, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(interstitial: DKMadsInterstitialAd, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onAdPresented(interstitial: DKMadsInterstitialAd) {}
        fun onAdDismissed(interstitial: DKMadsInterstitialAd) {}
    }

    var listener: Listener? = null
    var fullScreenContentCallback: DKMadsFullScreenContentCallback? = null
    var loadedAd: Ad? = null
        private set
    private var loadedAt: java.util.Date? = null
    override var responseInfo: DKMadsResponseInfo? = null
        private set

    var adWidth: Int = 0
    var adHeight: Int = 0

    fun load(
        context: Context,
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap(),
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        scope.launch {
            val sizes = bidSizes(adUnitId, adWidth, adHeight)
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.INTERSTITIAL,
                sizes = sizes,
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill) {
                        val msg = ad.reason ?: "no_fill"
                        listener?.onAdFailed(this@DKMadsInterstitialAd, msg, info)
                        return@fold
                    }
                    loadedAd = ad
                    loadedAt = java.util.Date()
                    listener?.onAdLoaded(this@DKMadsInterstitialAd, ad, info)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsInterstitialAd, err.message ?: "load failed", null)
                },
            )
        }
    }

    /** Presents a fullscreen activity. Call from an [Activity] context when possible. */
    fun show(context: Context) {
        val ad = loadedAd
        if (ad == null || !ad.hasFill) {
            listener?.onAdFailed(this, "no_fill", responseInfo)
            return
        }
        if (DKMadsAdCachePolicy.isExpired(loadedAt, AdFormat.INTERSTITIAL)) {
            listener?.onAdFailed(this, "ad_expired", responseInfo)
            fullScreenContentCallback?.onAdFailedToShowFullScreenContent("ad_expired")
            return
        }
        DKMadsInterstitialActivity.present(
            context = context,
            adUnitId = adUnitId,
            ad = ad,
            callbacks = DKMadsInterstitialActivity.Callbacks(
                onPresented = {
                    listener?.onAdPresented(this@DKMadsInterstitialAd)
                    fullScreenContentCallback?.onAdShowedFullScreenContent()
                },
                onDismissed = {
                    listener?.onAdDismissed(this@DKMadsInterstitialAd)
                    fullScreenContentCallback?.onAdDismissedFullScreenContent()
                },
                onRenderFailed = { msg ->
                    listener?.onAdFailed(this@DKMadsInterstitialAd, msg, responseInfo)
                    fullScreenContentCallback?.onAdFailedToShowFullScreenContent(msg)
                },
            ),
        )
    }

    fun destroy() {
        scope.cancel()
        loadedAd = null
        responseInfo = null
    }

    companion object {
        fun load(
            context: Context,
            adUnitId: String,
            adWidth: Int = 0,
            adHeight: Int = 0,
            placementCode: String? = null,
            placementContext: String? = null,
            keyValues: Map<String, Any> = emptyMap(),
            onComplete: (DKMadsInterstitialAd?, String?) -> Unit,
        ) {
            val interstitial = DKMadsInterstitialAd(adUnitId).apply {
                this.adWidth = adWidth
                this.adHeight = adHeight
                listener = object : Listener {
                    override fun onAdLoaded(interstitial: DKMadsInterstitialAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
                        onComplete(interstitial, null)
                    }

                    override fun onAdFailed(interstitial: DKMadsInterstitialAd, message: String, responseInfo: DKMadsResponseInfo?) {
                        onComplete(null, message)
                    }
                }
            }
            interstitial.load(context, placementCode, placementContext, keyValues)
        }

        /** IAB interstitial tokens for bid matching — not raw display pixel dimensions. */
        internal fun bidSizes(adUnitId: String, width: Int, height: Int): List<Pair<Int, Int>> {
            if (width > 0 && height > 0) return listOf(width to height)
            val registered = SSPSDK.registeredSizes(adUnitId)
            if (registered.isNotEmpty()) return registered
            return listOf(320 to 480)
        }
    }
}
