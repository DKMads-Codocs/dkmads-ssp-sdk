package com.dkmads.ssp

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Fullscreen rewarded presenter backed by the public bid API.
 * Rewards are granted only when video playback completes without skip/close.
 */
class DKMadsRewardedAd(
    override val adUnitId: String,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob()),
) : DKMadsFullScreenPresenting {
    interface Listener {
        fun onAdLoaded(rewarded: DKMadsRewardedAd, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(rewarded: DKMadsRewardedAd, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onAdPresented(rewarded: DKMadsRewardedAd) {}
        fun onUserEarnedReward(rewarded: DKMadsRewardedAd) {}
        fun onAdDismissed(rewarded: DKMadsRewardedAd) {}
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
            val sizes = DKMadsInterstitialAd.bidSizes(adUnitId, adWidth, adHeight)
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.REWARDED,
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
                        listener?.onAdFailed(this@DKMadsRewardedAd, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    loadedAd = ad
                    loadedAt = java.util.Date()
                    listener?.onAdLoaded(this@DKMadsRewardedAd, ad, info)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsRewardedAd, err.message ?: "load failed", null)
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
        if (DKMadsAdCachePolicy.isExpired(loadedAt, AdFormat.REWARDED)) {
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
                    listener?.onAdPresented(this@DKMadsRewardedAd)
                    fullScreenContentCallback?.onAdShowedFullScreenContent()
                },
                onDismissed = {
                    listener?.onAdDismissed(this@DKMadsRewardedAd)
                    fullScreenContentCallback?.onAdDismissedFullScreenContent()
                },
                onRenderFailed = { msg ->
                    listener?.onAdFailed(this@DKMadsRewardedAd, msg, responseInfo)
                    fullScreenContentCallback?.onAdFailedToShowFullScreenContent(msg)
                },
                onCompleted = { skipped ->
                    if (!skipped) listener?.onUserEarnedReward(this@DKMadsRewardedAd)
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
