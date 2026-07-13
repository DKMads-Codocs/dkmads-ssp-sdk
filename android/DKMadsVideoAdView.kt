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
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ProgressBar
import android.graphics.drawable.GradientDrawable
import android.widget.LinearLayout
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * Drop-in video / instream view. Loads, renders MP4/HLS (ExoPlayer) or HTML video `adm` (WebView), tracks lifecycle.
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
    private val videoContainer = FrameLayout(context)
    private val webView: WebView
    private var nativeVideo: DKMadsNativeVideoSurface? = null
    private var blurNative: DKMadsVideoBlurNativeSurface? = null
    private var chromeControlsRow: LinearLayout? = null
    private var chromeSkipSlot: FrameLayout? = null
    private var chromeScrim: View? = null
    private var skipButton: Button? = null
    private var muteButton: ImageButton? = null
    private var clickOverlay: View? = null
    private var progressBar: ProgressBar? = null
    private var isMuted = true
    private var ctaButton: Button? = null
    private var companionView: ImageView? = null
    private var skipRunnable: Runnable? = null
    private var progressRunnable: Runnable? = null
    private var videoTracker: VideoTracker? = null
    private var omidSession: DKMadsOmidSession? = null
    private var viewabilityStarted = false
    private var webContentReady = false
    private var playbackCompleted = false
    private var isPrepared = false
    private var isLoading = false
    private var loadGeneration = 0L
    private var lastRequestedPlacementContext: String? = null
    private var lastBidWidth: Int = 640
    private var lastBidHeight: Int = 360
    private var prepareTimeoutRunnable: Runnable? = null
    private var bufferTimeoutRunnable: Runnable? = null
    private var didAttemptWebFallback = false

    private companion object {
        const val INITIAL_LOAD_TIMEOUT_MS = 45_000L
        const val BUFFER_STALL_TIMEOUT_MS = 20_000L
        const val TAG_PACKAGED_CHROME = "dkmads_packaged_chrome"
    }

    init {
        setBackgroundColor(DKMadsCreativeChrome.letterboxBgColor)
        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            visibility = GONE
        }
        addView(videoContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(webView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    /** Renders an ad already returned from [SSPSDK.loadAd] (e.g. instream preload). */
    fun display(ad: Ad, responseInfo: DKMadsResponseInfo? = DKMadsResponseInfo.from(ad, requestFormat = "video")) {
        ++loadGeneration
        isLoading = false
        stopPlayback()
        if (!ad.hasVideoRenderableContent) {
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
        listener?.onAdLoaded(this, ad, responseInfo ?: DKMadsResponseInfo.from(ad, requestFormat = "video"))
        listener?.onAdImpression(this)
    }

    fun load(
        width: Int = 640,
        height: Int = 360,
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap(),
        sizes: List<Pair<Int, Int>>? = null,
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        if (isLoading) return
        val generation = ++loadGeneration
        isLoading = true
        lastRequestedPlacementContext = placementContext
        val bidSizes = sizes?.takeIf { it.isNotEmpty() } ?: listOf(width to height)
        lastBidWidth = bidSizes.first().first
        lastBidHeight = bidSizes.first().second
        stopPlayback()
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.VIDEO,
                sizes = bidSizes,
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            if (generation != loadGeneration) return@launch
            isLoading = false
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad, requestFormat = "video")
                    responseInfo = info
                    if (!ad.hasFill) {
                        listener?.onAdFailed(this@DKMadsVideoAdView, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    if (!ad.hasVideoRenderableContent) {
                        listener?.onAdFailed(
                            this@DKMadsVideoAdView,
                            "Video fill missing video_url or adm",
                            info,
                        )
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

    @SuppressLint("SetJavaScriptEnabled")
    private fun render(ad: Ad) {
        playbackCompleted = false
        didAttemptWebFallback = false
        cancelSkip()
        when (ad.preferredRenderer) {
            DKMadsCreativeRenderer.NATIVE_MP4 -> renderNative(ad)
            DKMadsCreativeRenderer.WEB_MARKUP -> renderWeb(ad)
        }
    }

    private fun failOrFallbackToWeb(ad: Ad, message: String) {
        if (tryFallbackToWebMarkup(ad)) return
        listener?.onAdFailed(this, message, responseInfo)
    }

    /** If native MP4/HLS fails but `adm` has `<video>`, retry in WebView instead of hard-failing. */
    private fun tryFallbackToWebMarkup(ad: Ad): Boolean {
        if (didAttemptWebFallback || !ad.hasWebVideoFallback) return false
        didAttemptWebFallback = true
        cancelPlaybackTimeouts()
        videoTracker?.stop()
        videoTracker = null
        omidSession?.finish()
        omidSession = null
        nativeVideo?.release()
        nativeVideo = null
        blurNative?.release()
        blurNative = null
        removeVideoChrome()
        removeVideoClickOverlay()
        renderWeb(ad)
        return true
    }

    private fun renderNative(ad: Ad) {
        val playbackUrl = ad.playableVideoUrl ?: return
        webView.visibility = GONE
        videoContainer.visibility = VISIBLE
        isPrepared = false
        cancelPlaybackTimeouts()
        nativeVideo?.release()
        nativeVideo = null
        blurNative?.release()
        blurNative = null

        if (ad.usesContainBlurLayout) {
            renderNativeBlur(ad, playbackUrl)
            return
        }

        nativeVideo = DKMadsNativeVideoSurface(context, videoContainer).also { surface ->
            isMuted = DKMadsVideoChrome.defaultPlaybackMuted(ad.unitFormat, ad.placementContext, ad.videoTemplate)
            prepareTimeoutRunnable = Runnable {
                if (!isPrepared && !playbackCompleted) {
                    failOrFallbackToWeb(ad, "Video playback timed out while loading")
                }
            }.also { postDelayed(it, INITIAL_LOAD_TIMEOUT_MS) }
            surface.play(
                url = playbackUrl,
                autoplay = autoplay,
                muted = isMuted,
                callbacks = object : DKMadsNativeVideoSurface.Callbacks {
                    override fun onReady(durationMs: Long) {
                        isPrepared = true
                        cancelPrepareTimeout()
                        attachVideoClickOverlay(ad)
                        setupVideoChrome(ad)
                        attachCompanion(ad)
                startOmidVideoSession(ad, surface.durationMs(), isMuted)
                videoTracker = SSPSDK.trackVideoLifecycle(
                    adUnitId = adUnitId,
                    campaignId = ad.campaignId,
                    creativeId = ad.creativeId ?: ad.id,
                            containerView = this@DKMadsVideoAdView,
                            durationMsProvider = { surface.durationMs() },
                            currentPositionMsProvider = { surface.currentPositionMs() },
                            isPlayingProvider = { surface.isPlaying() },
                    skippable = isSkippable,
                    eventListener = { event, _ -> forwardOmidVideoEvent(event) },
                )
                if (autoplay) {
                            listener?.onPlaybackStarted(this@DKMadsVideoAdView)
                }
                        startProgressUpdates(surface)
                post {
                    startViewability()
                    bringControlsToFront()
                }
            }

                    override fun onBuffering(buffering: Boolean) {
                        if (buffering) {
                            listener?.onPlaybackBuffering(this@DKMadsVideoAdView, true)
                            scheduleBufferStallTimeout(surface)
                        } else {
                            cancelBufferStallTimeout()
                            listener?.onPlaybackBuffering(this@DKMadsVideoAdView, false)
                        }
                    }

                    override fun onComplete() {
                        completePlayback(skipped = false)
                    }

                    override fun onError(message: String) {
                        cancelPlaybackTimeouts()
                        if (!isPrepared) {
                            failOrFallbackToWeb(ad, message)
                        } else {
                            listener?.onAdFailed(this@DKMadsVideoAdView, message, responseInfo)
                        }
                    }
                },
            )
        }
    }

    private fun renderNativeBlur(ad: Ad, playbackUrl: String) {
        blurNative = DKMadsVideoBlurNativeSurface(context, videoContainer).also { surface ->
            isMuted = DKMadsVideoChrome.defaultPlaybackMuted(ad.unitFormat, ad.placementContext, ad.videoTemplate)
            prepareTimeoutRunnable = Runnable {
                if (!isPrepared && !playbackCompleted) {
                    failOrFallbackToWeb(ad, "Video playback timed out while loading")
                }
            }.also { postDelayed(it, INITIAL_LOAD_TIMEOUT_MS) }
            surface.play(
                url = playbackUrl,
                autoplay = autoplay,
                muted = isMuted,
                callbacks = object : DKMadsVideoBlurNativeSurface.Callbacks {
                    override fun onReady(durationMs: Long) {
                        isPrepared = true
                        cancelPrepareTimeout()
                        attachVideoClickOverlay(ad)
                        setupVideoChrome(ad)
                        attachCompanion(ad)
                        startOmidVideoSession(ad, durationMs, isMuted)
                        videoTracker = SSPSDK.trackVideoLifecycle(
                            adUnitId = adUnitId,
                            campaignId = ad.campaignId,
                            creativeId = ad.creativeId ?: ad.id,
                            containerView = this@DKMadsVideoAdView,
                            durationMsProvider = { surface.durationMs() },
                            currentPositionMsProvider = { surface.currentPositionMs() },
                            isPlayingProvider = { surface.isPlaying() },
                            skippable = isSkippable,
                            eventListener = { event, _ -> forwardOmidVideoEvent(event) },
                        )
                        if (autoplay) {
                            listener?.onPlaybackStarted(this@DKMadsVideoAdView)
                        }
                        startBlurProgressUpdates(surface)
                        post {
                            startViewability()
                            bringControlsToFront()
                        }
                    }

                    override fun onBuffering(buffering: Boolean) {
                        listener?.onPlaybackBuffering(this@DKMadsVideoAdView, buffering)
                    }

                    override fun onComplete() {
                        completePlayback(skipped = false)
                    }

                    override fun onError(message: String) {
                        cancelPlaybackTimeouts()
                        if (!isPrepared) {
                            failOrFallbackToWeb(ad, message)
                        } else {
                            listener?.onAdFailed(this@DKMadsVideoAdView, message, responseInfo)
                        }
                    }
                },
            )
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun renderWeb(ad: Ad) {
        videoContainer.visibility = GONE
        nativeVideo?.release()
        nativeVideo = null
        blurNative?.release()
        blurNative = null
        webView.visibility = VISIBLE
        val renderSlot = if (ad.usesContainBlurLayout) {
            DKMadsVideoSlotFit.playerStageSize(width, height, lastBidWidth, lastBidHeight)
        } else {
            DKMadsBannerCreativeLayout.renderSlotSize(lastBidWidth, lastBidHeight, width, height)
        }
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                webContentReady = true
                view?.evaluateJavascript(
                    DKMadsBannerCreativeLayout.viewportInjectionScript(renderSlot.first, renderSlot.second),
                    null,
                )
                    listener?.onPlaybackStarted(this@DKMadsVideoAdView)
                // Packaged ADM chrome owns skip/mute/progress — do not add a second native Skip.
                if (webView.tag != TAG_PACKAGED_CHROME) {
                    setupVideoChrome(ad)
                }
                attachVideoClickOverlay(ad)
                bringControlsToFront()
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
        val packagedChrome = DKMadsVideoChrome.admHasPackagedChrome(ad.adm)
        var loadsPackagedChrome = false
        if (ad.adm.isNotBlank()) {
            val html = when {
                packagedChrome -> {
                    loadsPackagedChrome = true
                    ad.adm // keep house/VAST chrome as the single owner
                }
                ad.usesContainBlurLayout && DKMadsVideoSlotFit.admIncludesBlurStage(ad.adm) -> {
                    loadsPackagedChrome = packagedChrome
                    ad.adm
                }
                else -> DKMadsBannerCreativeLayout.htmlForBanner(ad.adm, renderSlot.first, renderSlot.second)
            }
            webView.tag = if (loadsPackagedChrome) TAG_PACKAGED_CHROME else null
            webView.loadDataWithBaseURL(
                "https://ssp.dkmads.com",
                html,
                "text/html",
                "UTF-8",
                null,
            )
        } else if (ad.html5EntryUrl.isNotBlank()) {
            webView.tag = null
            webView.loadUrl(ad.html5EntryUrl)
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
            omidSession?.signalVideoSkipped()
            emitVideoSkip()
        }
        videoTracker?.stop()
        videoTracker = null
        nativeVideo?.stop()
        blurNative?.stop()
        listener?.onAdComplete(this, skipped)
    }

    private fun startOmidVideoSession(ad: Ad, durationMs: Long, muted: Boolean) {
        if (omidSession != null || !DKMadsOmid.isAvailable) return
        omidSession = DKMadsOmid.provider
            ?.createVideoSession(context, this, ad.omidVerifications)
            ?.also {
                it.start()
                it.signalLoaded()
                it.signalVideoStart(durationMs / 1000f, if (muted) 0f else 1f)
            }
    }

    private fun forwardOmidVideoEvent(event: String) {
        val session = omidSession ?: return
        when (event) {
            "video_25" -> session.signalVideoFirstQuartile()
            "video_50" -> session.signalVideoMidpoint()
            "video_75" -> session.signalVideoThirdQuartile()
            "video_100" -> session.signalVideoComplete()
            "video_pause" -> session.signalVideoPaused()
            "video_resume" -> session.signalVideoResumed()
        }
    }

    private fun setupVideoChrome(ad: Ad) {
        if (chromeControlsRow != null) return
        ensureChromeBar(ad)
        attachMuteControl(ad)
        attachClickThroughCta(ad)
        attachProgressBar(ad)
        scheduleSkip(ad)
    }

    private fun ensureChromeBar(ad: Ad) {
        if (chromeControlsRow != null) return
        val density = resources.displayMetrics.density
        val template = ad.videoTemplate
        val bottomInset = DKMadsVideoChrome.chromeBottomInsetPx(
            context,
            DKMadsVideoChrome.showsProgress(template),
        )
        chromeScrim = View(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(0x73000000, Color.TRANSPARENT),
            )
        }
        val scrimLp = LayoutParams(LayoutParams.MATCH_PARENT, (48 * density).toInt(), Gravity.BOTTOM).apply {
            bottomMargin = bottomInset
        }
        addView(chromeScrim, scrimLp)

        val row = DKMadsVideoChrome.buildControlsRow(context)
        val rowLp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM).apply {
            bottomMargin = bottomInset
        }
        addView(row, rowLp)
        chromeControlsRow = row
        chromeSkipSlot = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
    }

    private fun attachMuteControl(ad: Ad) {
        val row = chromeControlsRow ?: return
        if (!DKMadsVideoChrome.showsMute(ad.videoTemplate)) return
        val btn = DKMadsVideoChrome.muteIconButton(context, isMuted)
        btn.setOnClickListener {
            isMuted = !isMuted
            nativeVideo?.setMuted(isMuted)
            blurNative?.setMuted(isMuted)
            DKMadsVideoChrome.updateMuteIcon(btn, isMuted)
        }
        row.addView(
            btn,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        muteButton = btn
        DKMadsVideoChrome.addWeightedSpacer(row)
    }

    private fun attachProgressBar(ad: Ad) {
        val template = ad.videoTemplate
        if (!DKMadsVideoChrome.showsProgress(template)) return
        val bar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
        }
        val lp = LayoutParams(LayoutParams.MATCH_PARENT, (3 * resources.displayMetrics.density).toInt().coerceAtLeast(3), Gravity.BOTTOM)
        addView(bar, lp)
        progressBar = bar
    }

    private fun attachVideoChrome(ad: Ad) {
        setupVideoChrome(ad)
    }

    private fun startBlurProgressUpdates(surface: DKMadsVideoBlurNativeSurface) {
        progressRunnable?.let { removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                val bar = progressBar
                if (bar != null && !playbackCompleted) {
                    val dur = surface.durationMs()
                    if (dur > 0) {
                        bar.progress = ((surface.currentPositionMs() * 100) / dur).toInt().coerceIn(0, 100)
                    }
                    postDelayed(this, 200)
                }
            }
        }
        progressRunnable = runnable
        post(runnable)
    }

    private fun startProgressUpdates(surface: DKMadsNativeVideoSurface) {
        progressRunnable?.let { removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                val bar = progressBar
                if (bar != null && !playbackCompleted) {
                    val dur = surface.durationMs()
                    if (dur > 0) {
                        bar.progress = ((surface.currentPositionMs() * 100) / dur).toInt().coerceIn(0, 100)
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
        muteButton = null
        chromeScrim?.let { removeView(it) }
        chromeScrim = null
        chromeControlsRow?.let { removeView(it) }
        chromeControlsRow = null
        chromeSkipSlot = null
        progressBar?.let { removeView(it) }
        progressBar = null
    }

    /** Keep Skip / mute / progress above companions and the click overlay for the whole ad. */
    private fun bringControlsToFront() {
        ctaButton?.bringToFront()
        chromeScrim?.bringToFront()
        progressBar?.bringToFront()
        // Chrome row (Skip + mute) last so Skip stays visible/tappable for the entire ad.
        chromeControlsRow?.bringToFront()
    }

    private fun scheduleSkip(ad: Ad) {
        if (!DKMadsVideoChrome.showsSkip(ad.videoTemplate, isSkippable)) return
        cancelSkip()
        ensureSkipSlotInRow()
        val slot = chromeSkipSlot ?: return
        var left = (skipOffsetMs / 1000).toInt().coerceAtLeast(0)
        val runnable = object : Runnable {
            override fun run() {
                if (playbackCompleted) return
                if (skipButton == null) {
                    val label = if (left <= 0) "Skip" else "Skip in ${left}s"
                    val btn = DKMadsVideoChrome.chromeButton(context, label).apply {
                        // Keep enabled so theme disabled-text color never hides the label.
                        isEnabled = true
                        isClickable = left <= 0
                        alpha = if (left <= 0) 1f else 0.85f
                        elevation = 24f
                        translationZ = 24f
                        if (left <= 0) {
                            setOnClickListener { completePlayback(skipped = true) }
                        }
                    }
                    slot.addView(
                        btn,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            Gravity.CENTER,
                        ),
                    )
                    skipButton = btn
                } else {
                    skipButton?.text = if (left <= 0) "Skip" else "Skip in ${left}s"
                    if (left <= 0) {
                        skipButton?.isEnabled = true
                        skipButton?.isClickable = true
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
        skipButton?.let { (it.parent as? ViewGroup)?.removeView(it) }
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
        addView(overlay, lp)
        clickOverlay = overlay
        // Overlay is full-bleed; chrome must stay above it for the whole ad.
        bringControlsToFront()
    }

    private fun removeVideoClickOverlay() {
        clickOverlay?.let { removeView(it) }
        clickOverlay = null
    }

    private fun attachClickThroughCta(ad: Ad) {
        removeClickThroughCta()
        removeCompanion()
        val style = DKMadsClickThroughCta.styleForAd(ad.videoTemplate, ad.ctaPosition)
        val chromeRow = if (style == VideoCtaStyle.DEFAULT) {
            chromeControlsRow ?: run {
                ensureChromeBar(ad)
                chromeControlsRow
            }
        } else {
            null
        }
        ctaButton = DKMadsClickThroughCta.attach(
            parent = this,
            clickUrl = ad.clickUrl,
            style = style,
            label = ad.ctaLabel,
            onClickThrough = { recordClick() },
            chromeRow = chromeRow,
        )
        if (chromeRow != null && chromeSkipSlot?.parent == null) {
            DKMadsVideoChrome.addWeightedSpacer(chromeRow)
            chromeSkipSlot?.let { chromeRow.addView(it) }
        }
    }

    private fun ensureSkipSlotInRow() {
        val row = chromeControlsRow ?: return
        val slot = chromeSkipSlot ?: return
        if (slot.parent != null) return
        DKMadsVideoChrome.addWeightedSpacer(row)
        row.addView(slot)
    }

    private fun removeClickThroughCta() {
        ctaButton?.let { removeView(it) }
        ctaButton = null
    }

    private fun attachCompanion(ad: Ad) {
        removeCompanion()
        val companionUrl = ad.companionImageUrl ?: return
        val density = resources.displayMetrics.density
        val image = ImageView(context).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            setBackgroundColor(Color.TRANSPARENT)
            maxHeight = (96 * density).toInt()
        }
        // Sit above the chrome bar so Skip/mute stay visible for the entire ad.
        val chromeClearance = DKMadsVideoChrome.chromeBottomInsetPx(
            context,
            DKMadsVideoChrome.showsProgress(ad.videoTemplate),
        ) + (36 * density).toInt()
        val lp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM).apply {
            val m = (4 * density).toInt()
            setMargins(m, m, m, chromeClearance)
        }
        addView(image, lp)
        companionView = image
        bringControlsToFront()
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
                bringControlsToFront()
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

    private fun effectivePlacementContext(ad: Ad): String? =
        ad.placementContext?.takeIf { it.isNotBlank() } ?: lastRequestedPlacementContext

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

    private fun scheduleBufferStallTimeout(surface: DKMadsNativeVideoSurface) {
        cancelBufferStallTimeout()
        bufferTimeoutRunnable = Runnable {
            if (!playbackCompleted && !surface.isPlaying()) {
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
        videoTracker?.stop()
        videoTracker = null
        omidSession?.finish()
        omidSession = null
        SSPSDK.stopVideoLifecycleTracking(adUnitId)
        nativeVideo?.release()
        nativeVideo = null
        blurNative?.release()
        blurNative = null
        videoContainer.visibility = GONE
        webView.loadDataWithBaseURL(null, "", "text/html", "UTF-8", null)
        webView.visibility = GONE
        loadedAd = null
        playbackCompleted = false
        isPrepared = false
        didAttemptWebFallback = false
    }

    fun destroy() {
        ++loadGeneration
        isLoading = false
        stopPlayback()
        scope.cancel()
        responseInfo = null
    }

    override fun onDetachedFromWindow() {
        stopViewability()
        super.onDetachedFromWindow()
    }
}
