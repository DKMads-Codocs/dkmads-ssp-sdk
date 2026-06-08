package com.dkmads.ssp

import android.annotation.SuppressLint
import android.app.Activity
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
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.VideoView
import android.media.MediaPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

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
        fun onPlaybackBuffering(view: DKMadsVideoAdView, buffering: Boolean) {}
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
    private var muteButton: ImageButton? = null
    private var clickOverlay: View? = null
    private var progressBar: ProgressBar? = null
    private var mediaPlayer: MediaPlayer? = null
    private var isMuted = true
    private var ctaButton: Button? = null
    private var companionView: ImageView? = null
    private var skipRunnable: Runnable? = null
    private var progressRunnable: Runnable? = null
    private var videoTracker: VideoTracker? = null
    private var viewabilityStarted = false
    private var webContentReady = false
    private var playbackCompleted = false
    private var isPrepared = false
    private var prepareTimeoutRunnable: Runnable? = null
    private var bufferTimeoutRunnable: Runnable? = null

    private companion object {
        const val INITIAL_LOAD_TIMEOUT_MS = 15_000L
        const val BUFFER_STALL_TIMEOUT_MS = 12_000L
    }

    init {
        setBackgroundColor(DKMadsCreativeChrome.letterboxBgColor)
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
        applySkipConfig(ad)
        this.responseInfo = responseInfo
        render(ad)
        if (!ad.impressionRecorded) {
            SSPSDK.recordAdImpression(
                adUnitId = adUnitId,
                adId = ad.id,
                campaignId = ad.campaignId,
                creativeId = ad.creativeId,
                dspSource = ad.dsp,
                reason = ad.reason,
            )
        }
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
                    applySkipConfig(ad)
                    render(ad)
                    SSPSDK.recordAdImpression(
                        adUnitId = adUnitId,
                        adId = ad.id,
                        campaignId = ad.campaignId,
                        creativeId = ad.creativeId,
                        dspSource = ad.dsp,
                        reason = ad.reason,
                    )
                    listener?.onAdLoaded(this@DKMadsVideoAdView, ad, info)
                    listener?.onAdImpression(this@DKMadsVideoAdView)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsVideoAdView, err.message ?: "load failed", null)
                },
            )
        }
    }

    private fun extractVideoSrcFromAdm(adm: String): String? {
        if (adm.isBlank()) return null
        val patterns = listOf(
            Regex("""<video[^>]+src=["']([^"']+)["']""", RegexOption.IGNORE_CASE),
            Regex("""<source[^>]+src=["']([^"']+)["']""", RegexOption.IGNORE_CASE),
        )
        for (pattern in patterns) {
            val src = pattern.find(adm)?.groupValues?.getOrNull(1)?.trim().orEmpty()
            if (src.isBlank()) continue
            val lower = src.lowercase()
            if (
                lower.contains(".mp4")
                || lower.contains(".m3u8")
                || lower.contains(".webm")
                || lower.contains("/api/public/creative-assets/")
            ) {
                return src
            }
        }
        return null
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun render(ad: Ad) {
        playbackCompleted = false
        cancelSkip()
        val playbackUrl = ad.videoUrl.ifBlank { extractVideoSrcFromAdm(ad.adm).orEmpty() }
        if (playbackUrl.isNotBlank()) {
            webView.visibility = GONE
            videoView.visibility = VISIBLE
            isPrepared = false
            cancelPlaybackTimeouts()
            val uri = Uri.parse(playbackUrl)
            videoView.setVideoURI(uri)
            prepareTimeoutRunnable = Runnable {
                if (!isPrepared && !playbackCompleted) {
                    listener?.onAdFailed(this, "Video playback timed out while loading", responseInfo)
                }
            }.also { postDelayed(it, INITIAL_LOAD_TIMEOUT_MS) }
            videoView.setOnPreparedListener { mp ->
                isPrepared = true
                cancelPrepareTimeout()
                mediaPlayer = mp
                isMuted = DKMadsVideoChrome.defaultPlaybackMuted(ad.unitFormat, ad.placementContext, ad.videoTemplate)
                mp.setVolume(if (isMuted) 0f else 1f, if (isMuted) 0f else 1f)
                attachVideoClickOverlay(ad)
                attachVideoChrome(ad)
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
                startProgressUpdates()
                post { startViewability() }
            }
            videoView.setOnInfoListener { _, what, _ ->
                when (what) {
                    MediaPlayer.MEDIA_INFO_BUFFERING_START -> {
                        listener?.onPlaybackBuffering(this, true)
                        scheduleBufferStallTimeout()
                    }
                    MediaPlayer.MEDIA_INFO_BUFFERING_END -> {
                        cancelBufferStallTimeout()
                        listener?.onPlaybackBuffering(this, false)
                    }
                }
                false
            }
            videoView.setOnCompletionListener { completePlayback(skipped = false) }
            videoView.setOnErrorListener { _, _, _ ->
                cancelPlaybackTimeouts()
                listener?.onAdFailed(this, "Video playback failed", responseInfo)
                true
            }
            attachClickThroughCta(ad)
            attachCompanion(ad)
            return
        }
        if (ad.adm.isNotBlank() || ad.isHtml5) {
            videoView.visibility = GONE
            webView.visibility = VISIBLE
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    webContentReady = true
                    listener?.onPlaybackStarted(this@DKMadsVideoAdView)
                    attachVideoChrome(ad)
                    attachVideoClickOverlay(ad)
                    post { startViewability() }
                }
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    if (!ClickThroughNavigation.shouldOpenLandingUri(
                            request?.url,
                            request?.isForMainFrame == true,
                            webContentReady,
                        )
                    ) {
                        return false
                    }
                    recordClick()
                    context.startActivity(Intent(Intent.ACTION_VIEW, request?.url))
                    return true
                }
            }
            webContentReady = false
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
        removeVideoChrome()
        removeVideoClickOverlay()
        stopProgressUpdates()
        if (skipped) {
            videoTracker?.markUserSkipped()
            emitVideoSkip()
        }
        videoTracker?.stop()
        videoTracker = null
        try {
            videoView.stopPlayback()
        } catch (_: Exception) { /* ignore */ }
        mediaPlayer = null
        listener?.onAdComplete(this, skipped)
    }

    private fun attachVideoChrome(ad: Ad) {
        removeVideoChrome()
        val template = ad.videoTemplate
        if (DKMadsVideoChrome.showsMute(template)) {
            val btn = DKMadsVideoChrome.muteIconButton(context, isMuted)
            btn.setOnClickListener {
                val mp = mediaPlayer ?: return@setOnClickListener
                isMuted = !isMuted
                mp.setVolume(if (isMuted) 0f else 1f, if (isMuted) 0f else 1f)
                DKMadsVideoChrome.updateMuteIcon(btn, isMuted)
            }
            val side = (10 * resources.displayMetrics.density).toInt()
            val bottom = DKMadsVideoChrome.chromeBottomInsetPx(context, DKMadsVideoChrome.showsProgress(template))
            val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.START).apply {
                setMargins(side, side, side, bottom)
            }
            addView(btn, lp)
            muteButton = btn
        }
        if (DKMadsVideoChrome.showsProgress(template)) {
            val bar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
                max = 100
            }
            val lp = LayoutParams(LayoutParams.MATCH_PARENT, (3 * resources.displayMetrics.density).toInt().coerceAtLeast(3), Gravity.BOTTOM)
            addView(bar, lp)
            progressBar = bar
        }
        scheduleSkip(ad)
    }

    private fun startProgressUpdates() {
        progressRunnable?.let { removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                val bar = progressBar
                if (bar != null && !playbackCompleted) {
                    val dur = videoView.duration
                    if (dur > 0) {
                        bar.progress = ((videoView.currentPosition * 100) / dur).coerceIn(0, 100)
                    }
                    postDelayed(this, 200)
                }
            }
        }
        progressRunnable = runnable
        post(runnable)
    }

    private fun stopProgressUpdates() {
        progressRunnable?.let { removeCallbacks(it) }
        progressRunnable = null
    }

    private fun removeVideoChrome() {
        muteButton?.let { removeView(it) }
        muteButton = null
        progressBar?.let { removeView(it) }
        progressBar = null
    }

    private fun scheduleSkip(ad: Ad) {
        if (!DKMadsVideoChrome.showsSkip(ad.videoTemplate, isSkippable)) return
        cancelSkip()
        var left = (skipOffsetMs / 1000).toInt().coerceAtLeast(0)
        val runnable = object : Runnable {
            override fun run() {
                if (playbackCompleted) return
                if (left <= 0 && skipButton == null) {
                    val btn = DKMadsVideoChrome.chromeButton(context, "Skip").apply {
                        setOnClickListener { completePlayback(skipped = true) }
                    }
                    val side = (10 * resources.displayMetrics.density).toInt()
                    val bottom = DKMadsVideoChrome.chromeBottomInsetPx(
                        context,
                        DKMadsVideoChrome.showsProgress(ad.videoTemplate),
                    )
                    val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.END).apply {
                        setMargins(side, side, side, bottom)
                    }
                    addView(btn, lp)
                    skipButton = btn
                    return
                }
                if (skipButton == null) {
                    val btn = DKMadsVideoChrome.chromeButton(context, "Skip in ${left}s").apply {
                        isEnabled = false
                        alpha = 0.85f
                    }
                    val side = (10 * resources.displayMetrics.density).toInt()
                    val bottom = DKMadsVideoChrome.chromeBottomInsetPx(
                        context,
                        DKMadsVideoChrome.showsProgress(ad.videoTemplate),
                    )
                    val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.END).apply {
                        setMargins(side, side, side, bottom)
                    }
                    addView(btn, lp)
                    skipButton = btn
                } else {
                    skipButton?.text = if (left <= 0) "Skip" else "Skip in ${left}s"
                    if (left <= 0) {
                        skipButton?.isEnabled = true
                        skipButton?.alpha = 1f
                        skipButton?.setOnClickListener { completePlayback(skipped = true) }
                        return
                    }
                }
                left -= 1
                postDelayed(this, 1000)
            }
        }
        skipRunnable = runnable
        post(runnable)
    }

    private fun cancelSkip() {
        skipRunnable?.let { removeCallbacks(it) }
        skipRunnable = null
        skipButton?.let { removeView(it) }
        skipButton = null
    }

    private fun attachVideoClickOverlay(ad: Ad) {
        removeVideoClickOverlay()
        if (ad.clickUrl.isBlank()) return
        val overlay = View(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = true
            setOnClickListener {
                recordClick()
                runCatching {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(ad.clickUrl))
                    if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
            }
        }
        val lp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        addView(overlay, 1, lp)
        clickOverlay = overlay
        videoView.isClickable = false
    }

    private fun removeVideoClickOverlay() {
        clickOverlay?.let { removeView(it) }
        clickOverlay = null
    }

    private fun attachClickThroughCta(ad: Ad) {
        removeClickThroughCta()
        removeCompanion()
        val style = DKMadsClickThroughCta.styleForAd(ad.videoTemplate, ad.ctaPosition)
        ctaButton = DKMadsClickThroughCta.attach(
            parent = this,
            clickUrl = ad.clickUrl,
            style = style,
            label = ad.ctaLabel,
            onClickThrough = { recordClick() },
        )
    }

    private fun removeClickThroughCta() {
        ctaButton?.let { removeView(it) }
        ctaButton = null
    }

    private fun attachCompanion(ad: Ad) {
        removeCompanion()
        val companionUrl = ad.companionImageUrl ?: return
        val image = ImageView(context).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            setBackgroundColor(Color.TRANSPARENT)
        }
        val lp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM).apply {
            val m = (4 * resources.displayMetrics.density).toInt()
            setMargins(m, m, m, m)
        }
        addView(image, lp)
        companionView = image
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                runCatching { URL(companionUrl).openStream().use { android.graphics.BitmapFactory.decodeStream(it) } }.getOrNull()
            }
            if (bitmap != null) {
                image.setImageBitmap(bitmap)
                val canClick = ad.showCompanionClick != false && ad.clickUrl.isNotBlank()
                if (canClick) {
                    image.setOnClickListener {
                        recordClick()
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(ad.clickUrl)))
                    }
                }
            } else {
                removeCompanion()
            }
        }
    }

    private fun removeCompanion() {
        companionView?.let { removeView(it) }
        companionView = null
    }

    private fun recordClick() {
        val ad = loadedAd ?: return
        SSPSDK.recordAdClick(adUnitId, ad.id, campaignId = ad.campaignId, creativeId = ad.creativeId, dspSource = ad.dsp)
        listener?.onAdClicked(this)
    }

    private fun applySkipConfig(ad: Ad) {
        ad.skippable?.let { isSkippable = it }
        val skipSec = ad.skipAfterSec
        if (skipSec != null && skipSec >= 0) {
            skipOffsetMs = (skipSec * 1000).toLong()
        }
    }

    private fun emitVideoSkip() {
        val ad = loadedAd ?: return
        val metadata = mutableMapOf<String, Any?>(
            "skippable" to true,
        )
        TelemetryManager.shared.trackEvent(
            "video_skip",
            mutableMapOf<String, Any?>(
                "ad_unit_id" to adUnitId,
                "campaign_id" to ad.campaignId,
                "creative_id" to (ad.creativeId ?: ad.id),
                "metadata" to metadata,
            ),
        )
    }

    private fun startViewability() {
        if (viewabilityStarted || !isAttachedToWindow || width <= 0 || height <= 0) return
        // Native video lifecycle already emits `video_viewable` at 50% / 2s.
        // Skip display viewability here to avoid double-counting one video impression twice.
        if (videoTracker != null) return
        viewabilityStarted = true
        SSPSDK.attachBannerViewability(
            adUnitId = adUnitId,
            container = this,
            campaignId = loadedAd?.campaignId,
            creativeId = loadedAd?.creativeId ?: loadedAd?.id,
            minExposureTimeMs = 2_000,
            onViewable = { listener?.onAdViewableImpression(this) },
        )
    }

    private fun stopViewability() {
        if (viewabilityStarted) {
            SSPSDK.detachBannerViewability(adUnitId)
            viewabilityStarted = false
        }
    }

    private fun cancelPrepareTimeout() {
        prepareTimeoutRunnable?.let { removeCallbacks(it) }
        prepareTimeoutRunnable = null
    }

    private fun cancelBufferStallTimeout() {
        bufferTimeoutRunnable?.let { removeCallbacks(it) }
        bufferTimeoutRunnable = null
    }

    private fun cancelPlaybackTimeouts() {
        cancelPrepareTimeout()
        cancelBufferStallTimeout()
    }

    private fun scheduleBufferStallTimeout() {
        cancelBufferStallTimeout()
        bufferTimeoutRunnable = Runnable {
            if (!playbackCompleted && !videoView.isPlaying) {
                listener?.onAdFailed(this, "Video playback stalled while buffering", responseInfo)
            }
        }.also { postDelayed(it, BUFFER_STALL_TIMEOUT_MS) }
    }

    fun stopPlayback() {
        stopViewability()
        removeClickThroughCta()
        cancelSkip()
        stopProgressUpdates()
        cancelPlaybackTimeouts()
        removeVideoChrome()
        removeVideoClickOverlay()
        mediaPlayer = null
        videoTracker?.stop()
        videoTracker = null
        SSPSDK.stopVideoLifecycleTracking(adUnitId)
        videoView.stopPlayback()
        videoView.visibility = GONE
        webView.loadDataWithBaseURL(null, "", "text/html", "UTF-8", null)
        webView.visibility = GONE
        loadedAd = null
        playbackCompleted = false
        isPrepared = false
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
