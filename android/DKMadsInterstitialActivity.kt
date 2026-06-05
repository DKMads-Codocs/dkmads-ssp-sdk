package com.dkmads.ssp

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.os.Build
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.VideoView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * Internal fullscreen presenter for [DKMadsInterstitialAd]. Not intended for direct use.
 */
class DKMadsInterstitialActivity : Activity() {

    data class Callbacks(
        val onPresented: () -> Unit = {},
        val onDismissed: () -> Unit = {},
        val onRenderFailed: (String) -> Unit = {},
        val onCompleted: (Boolean) -> Unit = {},
    )

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private lateinit var adUnitId: String
    private lateinit var ad: Ad
    private var callbacks: Callbacks = Callbacks()

    private lateinit var root: FrameLayout
    private lateinit var webView: WebView
    private lateinit var imageView: ImageView
    private lateinit var videoView: VideoView
    private var videoTracker: VideoTracker? = null
    private var viewabilityStarted = false
    private var ctaButton: Button? = null
    private var skipButton: Button? = null
    private var skipRunnable: Runnable? = null
    private var completionSignaled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = Color.BLACK
            window.navigationBarColor = Color.BLACK
        }
        adUnitId = intent.getStringExtra(EXTRA_AD_UNIT_ID).orEmpty()
        val payload = pendingPayload
        if (payload == null || adUnitId.isBlank()) {
            finish()
            return
        }
        ad = payload.first
        callbacks = payload.second
        pendingPayload = null

        root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        setContentView(root)
        setupChrome()
        when {
            ad.isVideo && ad.videoUrl.isNotBlank() -> presentVideo()
            ad.isHtml5 || ad.adm.isNotBlank() -> presentWeb()
            ad.creativeUrl.isNotBlank() -> presentImage()
            else -> failAndFinish("Interstitial creative is not video, image, or HTML5")
        }
        callbacks.onPresented()
    }

    override fun onDestroy() {
        stopViewability()
        removeVideoClickThroughCta()
        cancelVideoSkip()
        videoTracker?.stop()
        videoTracker = null
        scope.cancel()
        super.onDestroy()
    }

    private fun setupChrome() {
        val close = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.WHITE)
            setBackgroundColor(0x73000000.toInt())
            contentDescription = "Close"
            setOnClickListener { closeFromUser() }
        }
        val closeLp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.END,
        ).apply {
            val m = (12 * resources.displayMetrics.density).toInt()
            setMargins(m, m, m, m)
        }
        root.addView(close, closeLp)

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            visibility = View.GONE
        }
        imageView = ImageView(this).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            visibility = View.GONE
            setOnClickListener { onStaticClicked() }
        }
        videoView = VideoView(this).apply {
            visibility = View.GONE
            setOnCompletionListener {
                signalCompletion(skipped = false)
                finish()
            }
            setOnErrorListener { _, _, _ ->
                failAndFinish("Video playback failed")
                true
            }
        }
        val contentLp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        root.addView(videoView, 0, contentLp)
        root.addView(webView, 0, contentLp)
        root.addView(imageView, 0, contentLp)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun presentWeb() {
        webView.visibility = View.VISIBLE
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                view?.evaluateJavascript(DKMadsBannerCreativeLayout.FULLSCREEN_VIEWPORT_INJECTION_SCRIPT, null)
                startViewability()
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val uri = request?.url ?: return false
                if (!ClickThroughNavigation.matches(ad.clickUrl, uri.toString())) return false
                recordClick()
                startActivity(Intent(Intent.ACTION_VIEW, uri))
                return true
            }
        }
        if (ad.adm.isNotBlank()) {
            webView.loadDataWithBaseURL(
                "https://ssp.dkmads.com",
                DKMadsBannerCreativeLayout.htmlForFullscreen(ad.adm),
                "text/html",
                "UTF-8",
                null,
            )
        } else if (ad.html5EntryUrl.isNotBlank()) {
            webView.loadUrl(ad.html5EntryUrl)
        } else {
            failAndFinish("HTML5 interstitial missing adm or html5_entry_url")
        }
    }

    private fun presentImage() {
        imageView.visibility = View.VISIBLE
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                runCatching {
                    URL(ad.creativeUrl).openStream().use { BitmapFactory.decodeStream(it) }
                }.getOrNull()
            }
            if (bitmap != null) {
                imageView.setImageBitmap(bitmap)
                startViewability()
            } else {
                failAndFinish("Failed to load interstitial image")
            }
        }
    }

    private fun presentVideo() {
        videoView.visibility = View.VISIBLE
        val uri = Uri.parse(ad.videoUrl)
        videoView.setVideoURI(uri)
        videoView.setOnPreparedListener { mp ->
            videoTracker = SSPSDK.trackVideoLifecycle(
                adUnitId = adUnitId,
                campaignId = ad.campaignId,
                creativeId = ad.creativeId ?: ad.id,
                containerView = videoView,
                durationMsProvider = { mp.duration.coerceAtLeast(0).toLong() },
                currentPositionMsProvider = { videoView.currentPosition.toLong() },
                isPlayingProvider = { videoView.isPlaying },
                skippable = true,
            )
            videoView.start()
            attachVideoClickThroughCta()
            scheduleVideoSkip()
            startViewability()
        }
    }

    private fun attachVideoClickThroughCta() {
        removeVideoClickThroughCta()
        val style = DKMadsClickThroughCta.styleForAd(ad.videoTemplate, ad.ctaPosition)
        ctaButton = DKMadsClickThroughCta.attach(
            parent = root,
            clickUrl = ad.clickUrl,
            style = style,
            label = ad.ctaLabel,
            onClickThrough = { recordClick() },
        )
    }

    private fun removeVideoClickThroughCta() {
        ctaButton?.let { root.removeView(it) }
        ctaButton = null
    }

    private fun scheduleVideoSkip() {
        if (ad.skippable == false) return
        cancelVideoSkip()
        val skipAfterSec = ad.skipAfterSec?.takeIf { it >= 0 } ?: 5.0
        val runnable = Runnable {
            if (skipButton != null) return@Runnable
            val btn = Button(this).apply {
                text = "Skip"
                setTextColor(Color.WHITE)
                setBackgroundColor(0x8C000000.toInt())
                setOnClickListener {
                    videoTracker?.markUserSkipped()
                    try {
                        videoView.stopPlayback()
                    } catch (_: Exception) { /* ignore */ }
                    emitVideoSkip()
                    signalCompletion(skipped = true)
                    finish()
                }
            }
            val lp = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            ).apply {
                val m = (56 * resources.displayMetrics.density).toInt()
                setMargins(m, m, m, m)
            }
            root.addView(btn, lp)
            skipButton = btn
        }
        skipRunnable = runnable
        root.postDelayed(runnable, (skipAfterSec * 1000).toLong())
    }

    private fun cancelVideoSkip() {
        skipRunnable?.let { root.removeCallbacks(it) }
        skipRunnable = null
        skipButton?.let { root.removeView(it) }
        skipButton = null
    }

    private fun emitVideoSkip() {
        val metadata = mapOf("skippable" to true)
        TelemetryManager.shared.trackEvent(
            "video_skip",
            mapOf(
                "ad_unit_id" to adUnitId,
                "campaign_id" to ad.campaignId,
                "creative_id" to (ad.creativeId ?: ad.id),
                "metadata" to metadata,
            ),
        )
    }

    private fun onStaticClicked() {
        recordClick()
        val click = ad.clickUrl
        if (click.isNotBlank()) {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(click)))
        }
    }

    private fun recordClick() {
        SSPSDK.recordAdClick(
            adUnitId,
            ad.id,
            campaignId = ad.campaignId,
            creativeId = ad.creativeId,
            dspSource = ad.dsp,
        )
    }

    private fun startViewability() {
        if (viewabilityStarted || root.width <= 0 || root.height <= 0) return
        // Native video tracker emits `video_viewable` using 50%/2s.
        // Do not double-count with display viewability for the same video impression.
        if (videoTracker != null) return
        viewabilityStarted = true
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
        SSPSDK.attachBannerViewability(
            adUnitId = adUnitId,
            container = root,
            campaignId = ad.campaignId,
            creativeId = ad.creativeId ?: ad.id,
            minExposureTimeMs = if (ad.isVideo) 2_000 else 1_000,
        )
    }

    private fun stopViewability() {
        if (viewabilityStarted) {
            SSPSDK.detachBannerViewability(adUnitId)
            viewabilityStarted = false
        }
    }

    private fun failAndFinish(message: String) {
        callbacks.onRenderFailed(message)
        finish()
    }

    private fun signalCompletion(skipped: Boolean) {
        if (completionSignaled) return
        completionSignaled = true
        callbacks.onCompleted(skipped)
    }

    private fun closeFromUser() {
        if (ad.isVideo) {
            signalCompletion(skipped = true)
        }
        finish()
    }

    override fun finish() {
        callbacks.onDismissed()
        super.finish()
    }

    companion object {
        private const val EXTRA_AD_UNIT_ID = "dkmads_interstitial_ad_unit_id"
        private var pendingPayload: Pair<Ad, Callbacks>? = null

        fun present(context: Context, adUnitId: String, ad: Ad, callbacks: Callbacks) {
            pendingPayload = ad to callbacks
            val intent = Intent(context, DKMadsInterstitialActivity::class.java).apply {
                putExtra(EXTRA_AD_UNIT_ID, adUnitId)
                if (context !is Activity) {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            context.startActivity(intent)
        }
    }
}
