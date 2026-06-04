package com.dkmads.ssp

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Loads native format and exposes [DKMadsNativeAdAssets] for custom in-feed UI.
 * Use [DKMadsNativeAdView] when you want the default WebView/image render.
 */
class DKMadsNativeAd(
    val adUnitId: String,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob()),
) {
    interface Listener {
        fun onAdLoaded(native: DKMadsNativeAd, ad: Ad, assets: DKMadsNativeAdAssets, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(native: DKMadsNativeAd, message: String, responseInfo: DKMadsResponseInfo?) {}
    }

    var listener: Listener? = null
    var loadedAd: Ad? = null
        private set
    var assets: DKMadsNativeAdAssets? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    fun load(
        context: Context,
        width: Int = 320,
        height: Int = 50,
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap(),
    ) {
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.NATIVE,
                sizes = listOf(width to height),
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill) {
                        listener?.onAdFailed(this@DKMadsNativeAd, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    loadedAd = ad
                    assets = DKMadsNativeAdAssets.from(ad)
                    listener?.onAdLoaded(this@DKMadsNativeAd, ad, assets!!, info)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsNativeAd, err.message ?: "load failed", null)
                },
            )
        }
    }

    fun destroy() {
        scope.cancel()
        loadedAd = null
        assets = null
        responseInfo = null
    }
}
