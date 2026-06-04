package com.dkmads.ssp

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * App open / splash fullscreen ad (dashboard format `splash`). Show on cold start or resume.
 */
class DKMadsAppOpenAd(
    override val adUnitId: String,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob()),
) : DKMadsFullScreenPresenting {
    interface Listener {
        fun onAdLoaded(appOpen: DKMadsAppOpenAd, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(appOpen: DKMadsAppOpenAd, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onAdPresented(appOpen: DKMadsAppOpenAd) {}
        fun onAdDismissed(appOpen: DKMadsAppOpenAd) {}
    }

    var listener: Listener? = null
    var fullScreenContentCallback: DKMadsFullScreenContentCallback? = null
    var loadedAd: Ad? = null
        private set
    private var loadedAt: java.util.Date? = null
    override var responseInfo: DKMadsResponseInfo? = null
        private set

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
            val sizes = DKMadsInterstitialAd.bidSizes(adUnitId, 0, 0)
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.SPLASH,
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
                        listener?.onAdFailed(this@DKMadsAppOpenAd, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    loadedAd = ad
                    loadedAt = java.util.Date()
                    listener?.onAdLoaded(this@DKMadsAppOpenAd, ad, info)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsAppOpenAd, err.message ?: "load failed", null)
                },
            )
        }
    }

    fun show(context: Context) {
        val ad = loadedAd
        if (ad == null || !ad.hasFill) {
            listener?.onAdFailed(this, "no_fill", responseInfo)
            return
        }
        if (DKMadsAdCachePolicy.isExpired(loadedAt, AdFormat.SPLASH)) {
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
                    listener?.onAdPresented(this)
                    fullScreenContentCallback?.onAdShowedFullScreenContent()
                },
                onDismissed = {
                    listener?.onAdDismissed(this)
                    fullScreenContentCallback?.onAdDismissedFullScreenContent()
                },
                onRenderFailed = { msg ->
                    listener?.onAdFailed(this, msg, responseInfo)
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
}
