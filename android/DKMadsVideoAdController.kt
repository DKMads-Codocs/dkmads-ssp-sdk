package com.dkmads.ssp

import android.net.Uri
import android.view.View
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Loads a video ad and attaches quartile / skip / viewability telemetry via [SSPSDK.trackVideoLifecycle].
 */
class DKMadsVideoAdController(
    val adUnitId: String,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob()),
) {
    interface Listener {
        fun onAdLoaded(ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onVideoEvent(eventName: String, payload: Map<String, Any?>) {}
    }

    var listener: Listener? = null
    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private var tracker: VideoTracker? = null

    fun load(
        context: android.content.Context,
        width: Int = 640,
        height: Int = 360,
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap(),
    ) {
        detach()
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.VIDEO,
                sizes = listOf(width to height),
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill || (ad.videoUrl.isBlank() && ad.adm.isBlank())) {
                        listener?.onAdFailed(
                            if (ad.videoUrl.isBlank() && ad.adm.isBlank() && ad.hasFill) {
                                "Video fill missing video_url (MP4 or HLS)."
                            } else {
                                ad.reason ?: "no_fill"
                            },
                            info,
                        )
                        return@fold
                    }
                    loadedAd = ad
                    listener?.onAdLoaded(ad, info)
                },
                onFailure = { err ->
                    listener?.onAdFailed(err.message ?: "load failed", null)
                },
            )
        }
    }

    /** HTTPS MP4 / HLS URL for ExoPlayer, MediaPlayer, or VideoView. */
    fun playbackUri(): Uri? = loadedAd?.videoUrl?.takeIf { it.isNotBlank() }?.let { Uri.parse(it) }

    fun attach(
        containerView: View,
        durationMsProvider: () -> Long,
        currentPositionMsProvider: () -> Long,
        isPlayingProvider: () -> Boolean,
        isMutedProvider: () -> Boolean = { false },
        skippable: Boolean? = null,
    ) {
        detach()
        tracker = SSPSDK.trackVideoLifecycle(
            adUnitId = adUnitId,
            campaignId = loadedAd?.campaignId,
            creativeId = loadedAd?.creativeId ?: loadedAd?.id,
            containerView = containerView,
            durationMsProvider = durationMsProvider,
            currentPositionMsProvider = currentPositionMsProvider,
            isPlayingProvider = isPlayingProvider,
            isMutedProvider = isMutedProvider,
            skippable = skippable,
            eventListener = { event, payload ->
                listener?.onVideoEvent(event, payload)
            },
        )
    }

    fun detach() {
        tracker?.stop()
        tracker = null
        SSPSDK.stopVideoLifecycleTracking(adUnitId)
    }

    fun destroy() {
        detach()
        scope.cancel()
        loadedAd = null
        responseInfo = null
    }
}
