package com.dkmads.ssp

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.VideoView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Drop-in video / instream view. Loads, renders MP4 (VideoView) or HTML video `adm` (WebView), tracks lifecycle.
 */
class DKMadsVideoAdView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
    var adUnitId: String = "",
) : FrameLayout(context, attrs, defStyleAttr) {

    interface Listener {
        fun onAdLoaded(view: DKMadsVideoAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(view: DKMadsVideoAdView, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onPlaybackStarted(view: DKMadsVideoAdView) {}
        fun onAdComplete(view: DKMadsVideoAdView, skipped: Boolean) {}
        fun onAdClicked(view: DKMadsVideoAdView) {}
        fun onAdImpression(view: DKMadsVideoAdView) {}
        fun onAdViewableImpression(view: DKMadsVideoAdView) {}
    }

    var listener: Listener? = null
    var autoplay: Boolean = true
    var isSkippable: Boolean = true
    var skipOffsetMs: Long = 5_000L

    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val videoView: VideoView
    private val webView: WebView
    private var skipButton: Button? = null
    private var skipRunnable: Runnable? = null
    private var videoTracker: VideoTracker? = null
    private var viewabilityStarted = false
    private var playbackCompleted = false

    init {
        setBackgroundColor(Color.BLACK)
        videoView = VideoView(context).apply { visibility = GONE }
        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            visibility = GONE
        }
        addView(videoView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(webView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    /** Renders an ad already returned from [SSPSDK.loadAd] (e.g. instream preload). */
    fun display(ad: Ad, responseInfo: DKMadsResponseInfo? = DKMadsResponseInfo.from(ad)) {
        stopPlayback()
        if (!ad.isVideo || (ad.videoUrl.isBlank() && ad.adm.isBlank())) {
            listener?.onAdFailed(this, "Video fill missing video_url or adm", responseInfo)
            return
        }
        loadedAd = ad
        this.responseInfo = responseInfo
        render(ad)
        listener?.onAdLoaded(this, ad, responseInfo ?: DKMadsResponseInfo.from(ad))
        listener?.onAdImpression(this)
    }

    fun load(
        width: Int = 640,
        height: Int = 360,
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap(),
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        stopPlayback()
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
                    if (!ad.hasFill || !ad.isVideo) {
                        listener?.onAdFailed(this@DKMadsVideoAdView, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    if (ad.videoUrl.isBlank() && ad.adm.isBlank()) {
                        listener?.onAdFailed(this@DKMadsVideoAdView, "Video fill missing video_url", info)
                        return@fold
                    }
                    loadedAd = ad
                    render(ad)
                    listener?.onAdLoaded(this@DKMadsVideoAdView, ad, info)
                    listener?.onAdImpression(this@DKMadsVideoAdView)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsVideoAdView, err.message ?: "load failed", null)
                },
            )
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun render(ad: Ad) {
        playbackCompleted = false
        cancelSkip()
        if (ad.videoUrl.isNotBlank()) {
            webView.visibility = GONE
            videoView.visibility = VISIBLE
            val uri = Uri.parse(ad.videoUrl)
            videoView.setVideoURI(uri)
            videoView.setOnPreparedListener { mp ->
                videoTracker = SSPSDK.trackVideoLifecycle(
                    adUnitId = adUnitId,
                    campaignId = ad.campaignId,
                    creativeId = ad.creativeId ?: ad.id,
                    containerView = this,
                    durationMsProvider = { mp.duration.coerceAtLeast(0).toLong() },
                    currentPositionMsProvider = { videoView.currentPosition.toLong() },
                    isPlayingProvider = { videoView.isPlaying },
                    skippable = isSkippable,
                )
                if (autoplay) {
                    videoView.start()
                    listener?.onPlaybackStarted(this)
                }
                scheduleSkip()
                post { startViewability() }
            }
            videoView.setOnCompletionListener { completePlayback(skipped = false) }
            videoView.setOnErrorListener { _, _, _ ->
                listener?.onAdFailed(this, "Video playback failed", responseInfo)
                true
            }
            return
        }
        if (ad.adm.isNotBlank() || ad.isHtml5) {
            videoView.visibility = GONE
            webView.visibility = VISIBLE
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    listener?.onPlaybackStarted(this@DKMadsVideoAdView)
                    scheduleSkip()
                    post { startViewability() }
                }
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val uri = request?.url ?: return false
                    recordClick()
                    context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    return true
                }
            }
            if (ad.adm.isNotBlank()) {
                webView.loadDataWithBaseURL("https://ssp.dkmads.com", ad.adm, "text/html", "UTF-8", null)
            } else if (ad.html5EntryUrl.isNotBlank()) {
                webView.loadUrl(ad.html5EntryUrl)
            }
        }
    }

    private fun completePlayback(skipped: Boolean) {
        if (playbackCompleted) return
        playbackCompleted = true
        cancelSkip()
        listener?.onAdComplete(this, skipped)
    }

    private fun scheduleSkip() {
        if (!isSkippable) return
        cancelSkip()
        val runnable = Runnable {
            if (playbackCompleted || skipButton != null) return@Runnable
            val btn = Button(context).apply {
                text = "Skip"
                setTextColor(Color.WHITE)
                setBackgroundColor(0x8C000000.toInt())
                setOnClickListener { completePlayback(skipped = true) }
            }
            val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END).apply {
                val m = (12 * resources.displayMetrics.density).toInt()
                setMargins(m, m, m, m)
            }
            addView(btn, lp)
            skipButton = btn
        }
        skipRunnable = runnable
        postDelayed(runnable, skipOffsetMs)
    }

    private fun cancelSkip() {
        skipRunnable?.let { removeCallbacks(it) }
        skipRunnable = null
        skipButton?.let { removeView(it) }
        skipButton = null
    }

    private fun recordClick() {
        val ad = loadedAd ?: return
        SSPSDK.recordAdClick(adUnitId, ad.id, campaignId = ad.campaignId, creativeId = ad.creativeId, dspSource = ad.dsp)
        listener?.onAdClicked(this)
    }

    private fun startViewability() {
        if (viewabilityStarted || !isAttachedToWindow || width <= 0 || height <= 0) return
        viewabilityStarted = true
        SSPSDK.attachBannerViewability(
            adUnitId = adUnitId,
            container = this,
            creativeId = loadedAd?.id,
            onViewable = { listener?.onAdViewableImpression(this) },
        )
    }

    private fun stopViewability() {
        if (viewabilityStarted) {
            SSPSDK.detachBannerViewability(adUnitId)
            viewabilityStarted = false
        }
    }

    fun stopPlayback() {
        stopViewability()
        cancelSkip()
        videoTracker?.stop()
        videoTracker = null
        SSPSDK.stopVideoLifecycleTracking(adUnitId)
        videoView.stopPlayback()
        videoView.visibility = GONE
        webView.loadDataWithBaseURL(null, "", "text/html", "UTF-8", null)
        webView.visibility = GONE
        loadedAd = null
        playbackCompleted = false
    }

    fun destroy() {
        stopPlayback()
        scope.cancel()
        responseInfo = null
    }

    override fun onDetachedFromWindow() {
        stopViewability()
        super.onDetachedFromWindow()
    }
}
