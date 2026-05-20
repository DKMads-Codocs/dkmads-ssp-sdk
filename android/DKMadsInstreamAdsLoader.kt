package com.dkmads.ssp

import android.view.View
import android.widget.FrameLayout

/**
 * IMA-style instream coordinator: pauses host content, plays ad in [adContainer], optionally resumes content.
 *
 * Wire your ExoPlayer / MediaPlayer via [DKMadsContentPlayback] (or use lambdas in the secondary constructor).
 */
class DKMadsInstreamAdsLoader(
    private val adContainer: FrameLayout,
    private val contentPlayback: DKMadsContentPlayback,
) {
    constructor(
        adContainer: FrameLayout,
        onPauseContent: () -> Unit,
        onResumeContent: () -> Unit,
        wasContentPlaying: () -> Boolean = { false },
    ) : this(
        adContainer,
        object : DKMadsContentPlayback {
            override fun pauseContent() = onPauseContent()
            override fun resumeContent() = onResumeContent()
            override fun wasContentPlaying(): Boolean = wasContentPlaying()
        },
    )

    interface Listener {
        fun onAdStarted(loader: DKMadsInstreamAdsLoader) {}
        fun onAdFinished(loader: DKMadsInstreamAdsLoader) {}
        fun onAdFailed(loader: DKMadsInstreamAdsLoader, message: String) {}
    }

    var listener: Listener? = null
    var pauseContentAutomatically: Boolean = true
    var resumeContentAfterAd: Boolean = true
    var hidesAdContainerWhenFinished: Boolean = true

    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private var videoAdView: DKMadsVideoAdView? = null
    private var didPauseContentForAd = false

    fun requestAds(
        adUnitId: String,
        contentPosition: String? = null,
        width: Int = 640,
        height: Int = 360,
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required")
            return
        }
        loadedAd = null
        responseInfo = null
        clearAdOverlay(resetAnalytics = true)
        adContainer.visibility = View.VISIBLE

        val view = DKMadsVideoAdView(adContainer.context, adUnitId = adUnitId).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            isSkippable = true
            listener = instreamVideoListener
        }
        adContainer.addView(view)
        videoAdView = view

        didPauseContentForAd = false
        if (pauseContentAutomatically) {
            contentPlayback.pauseContent()
            didPauseContentForAd = true
        }

        view.load(
            width = width,
            height = height,
            placementContext = contentPosition,
        )
    }

    fun destroy() {
        clearAdOverlay(resetAnalytics = true)
    }

    private fun clearAdOverlay(resetAnalytics: Boolean) {
        videoAdView?.destroy()
        videoAdView = null
        adContainer.removeAllViews()
        if (hidesAdContainerWhenFinished) {
            adContainer.visibility = View.GONE
        }
        if (resetAnalytics) {
            loadedAd = null
            responseInfo = null
        }
    }

    private fun syncFromVideoView() {
        loadedAd = videoAdView?.loadedAd
        responseInfo = videoAdView?.responseInfo
    }

    private fun resumeContentIfNeeded() {
        if (!resumeContentAfterAd) return
        if (didPauseContentForAd || contentPlayback.wasContentPlaying()) {
            contentPlayback.resumeContent()
        }
        didPauseContentForAd = false
    }

    private val instreamVideoListener = object : DKMadsVideoAdView.Listener {
        override fun onAdLoaded(view: DKMadsVideoAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {
            syncFromVideoView()
            listener?.onAdStarted(this@DKMadsInstreamAdsLoader)
        }

        override fun onAdFailed(view: DKMadsVideoAdView, message: String, responseInfo: DKMadsResponseInfo?) {
            syncFromVideoView()
            clearAdOverlay(resetAnalytics = false)
            resumeContentIfNeeded()
            listener?.onAdFailed(this@DKMadsInstreamAdsLoader, message)
        }

        override fun onPlaybackStarted(view: DKMadsVideoAdView) {
            syncFromVideoView()
            listener?.onAdStarted(this@DKMadsInstreamAdsLoader)
        }

        override fun onAdComplete(view: DKMadsVideoAdView, skipped: Boolean) {
            syncFromVideoView()
            clearAdOverlay(resetAnalytics = false)
            resumeContentIfNeeded()
            listener?.onAdFinished(this@DKMadsInstreamAdsLoader)
        }
    }
}

/** Host content player hooks for [DKMadsInstreamAdsLoader] (e.g. ExoPlayer pause/play). */
interface DKMadsContentPlayback {
    fun pauseContent()
    fun resumeContent()
    fun wasContentPlaying(): Boolean = false
}
