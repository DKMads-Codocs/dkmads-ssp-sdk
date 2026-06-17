package com.dkmads.ssp

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.AttributeSet
import android.view.View
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView
import java.io.ByteArrayInputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.os.Handler
import android.os.Looper
import java.net.URL

/**
 * Drop-in banner view. Auto-tracks IAB viewability after render.
 */
class DKMadsBannerAdView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
    var adUnitId: String = "",
    private var adWidth: Int = 300,
    private var adHeight: Int = 250,
) : FrameLayout(context, attrs, defStyleAttr) {

    interface Listener {
        fun onAdLoaded(view: DKMadsBannerAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(view: DKMadsBannerAdView, error: String, responseInfo: DKMadsResponseInfo?) {}
        fun onAdClicked(view: DKMadsBannerAdView) {}
        fun onAdImpression(view: DKMadsBannerAdView) {}
        fun onAdViewableImpression(view: DKMadsBannerAdView) {}
    }

    var listener: Listener? = null
    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val refreshHandler = Handler(Looper.getMainLooper())
    private var refreshRunnable: Runnable? = null
    private data class BannerLoadParams(
        val placementCode: String? = null,
        val placementContext: String? = null,
        val keyValues: Map<String, Any> = emptyMap(),
        val bidSizes: List<Pair<Int, Int>>? = null,
    )
    private var lastLoadParams: BannerLoadParams? = null
    private val webView: WebView
    private val imageView: ImageView
    private var viewabilityStarted = false
    private var webContentReady = false
    private var isLoading = false
    private var loadGeneration = 0L
    private var mraid: DKMadsMraidController? = null
    private var omidSession: DKMadsOmidSession? = null

    init {
        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            visibility = GONE
        }
        imageView = ImageView(context).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            visibility = GONE
            setOnClickListener { onBannerClicked() }
        }
        addView(webView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(imageView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    /** IAB size metadata for bidding only — does not set view layout (use ConstraintLayout / dp for layout). */
    fun setAdSize(width: Int, height: Int) {
        adWidth = width
        adHeight = height
    }

    /**
     * @param sizes Optional IAB bid tokens (e.g. `listOf(300 to 250)`). When omitted, uses [setAdSize].
     * Render/viewport always follows laid-out view bounds.
     */
    fun load(
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any>? = null,
        sizes: List<Pair<Int, Int>>? = null,
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        if (isLoading) return
        val generation = ++loadGeneration
        isLoading = true
        val resolved = normalizeLoadParams(
            BannerLoadParams(
                placementCode = placementCode ?: lastLoadParams?.placementCode,
                placementContext = placementContext ?: lastLoadParams?.placementContext,
                keyValues = keyValues ?: lastLoadParams?.keyValues ?: emptyMap(),
                bidSizes = sizes ?: lastLoadParams?.bidSizes,
            ),
        )
        lastLoadParams = resolved
        stopViewability()
        clearCreative()
        val bidSizes = resolved.bidSizes?.takeIf { it.isNotEmpty() }
            ?: listOf(DKMadsBannerCreativeLayout.bidSlotSize(adWidth, adHeight))
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.BANNER,
                sizes = bidSizes,
                placementCode = resolved.placementCode,
                placementContext = resolved.placementContext,
                keyValues = resolved.keyValues,
            )
            if (generation != loadGeneration) return@launch
            isLoading = false
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill) {
                        listener?.onAdFailed(this@DKMadsBannerAdView, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    loadedAd = ad
                    render(ad)
                    SSPSDK.recordAdImpression(
                        adUnitId = adUnitId,
                        adId = ad.id,
                        campaignId = ad.campaignId,
                        creativeId = ad.creativeId,
                        dspSource = ad.dsp,
                        reason = ad.reason,
                    )
                    listener?.onAdLoaded(this@DKMadsBannerAdView, ad, info)
                    listener?.onAdImpression(this@DKMadsBannerAdView)
                    post { startViewability() }
                    scheduleRefresh(ad.refreshIntervalSec)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsBannerAdView, err.message ?: "load failed", null)
                },
            )
        }
    }

    private fun render(ad: Ad) {
        val renderSlot = DKMadsBannerCreativeLayout.renderSlotSize(adWidth, adHeight, width, height)
        val preferImage = ad.renderModeHint == "image" && ad.creativeUrl.isNotBlank()
        if (!preferImage && (ad.isHtml5 || ad.adm.isNotBlank())) {
            webView.visibility = VISIBLE
            imageView.visibility = GONE
            @SuppressLint("SetJavaScriptEnabled")
            webView.settings.javaScriptEnabled = true
            val mraidController = if (ad.isMraidCreative) {
                DKMadsMraidController(webView, "inline", bannerMraidHost()).also {
                    it.attach()
                    mraid = it
                }
            } else {
                mraid = null
                null
            }
            webView.webViewClient = object : WebViewClient() {
                override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                    mraidController?.injectScript()
                }
                override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                    val path = request?.url?.lastPathSegment
                    if (mraidController != null && path == "mraid.js") {
                        return WebResourceResponse(
                            "application/javascript",
                            "UTF-8",
                            ByteArrayInputStream(DKMadsMraidScript.JS.toByteArray(Charsets.UTF_8)),
                        )
                    }
                    return super.shouldInterceptRequest(view, request)
                }
                override fun onPageFinished(view: WebView?, url: String?) {
                    webContentReady = true
                    view?.evaluateJavascript(
                        DKMadsBannerCreativeLayout.viewportInjectionScript(renderSlot.first, renderSlot.second),
                        null,
                    )
                    mraidController?.notifyReady()
                    startOmidHtmlSession()
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
                    onBannerClicked(request?.url)
                    return true
                }
            }
            webContentReady = false
            if (ad.adm.isNotBlank()) {
                webView.loadDataWithBaseURL(
                    "https://ssp.dkmads.com",
                    DKMadsBannerCreativeLayout.htmlForBanner(ad.adm, renderSlot.first, renderSlot.second),
                    "text/html",
                    "UTF-8",
                    null,
                )
            } else if (ad.html5EntryUrl.isNotBlank()) {
                webView.loadUrl(ad.html5EntryUrl)
            }
            return
        }
        val url = ad.creativeUrl
        if (url.isNotBlank()) {
            webView.visibility = GONE
            imageView.visibility = VISIBLE
            scope.launch {
                val bitmap = withContext(Dispatchers.IO) {
                    runCatching {
                        URL(url).openStream().use { BitmapFactory.decodeStream(it) }
                    }.getOrNull()
                }
                if (bitmap != null) {
                    imageView.setImageBitmap(bitmap)
                    startOmidNativeSession()
                    post { startViewability() }
                }
            }
        }
    }

    private fun startOmidNativeSession() {
        if (omidSession != null || !DKMadsOmid.isAvailable) return
        val ad = loadedAd ?: return
        omidSession = DKMadsOmid.provider
            ?.createNativeDisplaySession(context, this, ad.omidVerifications)
            ?.also {
                it.start()
                it.signalLoaded()
            }
    }

    private fun onBannerClicked(openUri: Uri? = null) {
        val ad = loadedAd ?: return
        SSPSDK.recordAdClick(
            adUnitId,
            ad.id,
            campaignId = ad.campaignId,
            creativeId = ad.creativeId,
            dspSource = ad.dsp,
        )
        listener?.onAdClicked(this)
        val destination = openUri ?: ad.clickUrl.takeIf { it.isNotBlank() }?.let { Uri.parse(it) }
        if (destination != null) {
            context.startActivity(Intent(Intent.ACTION_VIEW, destination))
        }
    }

    private fun startViewability() {
        if (viewabilityStarted || !isAttachedToWindow || width <= 0 || height <= 0) return
        viewabilityStarted = true
        SSPSDK.attachBannerViewability(
            adUnitId = adUnitId,
            container = this,
            campaignId = loadedAd?.campaignId,
            creativeId = loadedAd?.creativeId ?: loadedAd?.id,
            onViewable = {
                mraid?.setViewable(true)
                omidSession?.signalImpression()
                listener?.onAdViewableImpression(this@DKMadsBannerAdView)
            },
        )
    }

    private fun startOmidHtmlSession() {
        if (omidSession != null || !DKMadsOmid.isAvailable) return
        omidSession = DKMadsOmid.provider?.createHtmlDisplaySession(context, webView)?.also {
            it.start()
            it.signalLoaded()
        }
    }

    private fun bannerMraidHost(): DKMadsMraidHost = object : DKMadsMraidHost {
        override fun onMraidOpen(url: String) {
            onBannerClicked(Uri.parse(url))
        }
        override fun onMraidClose() {
            mraid?.setViewable(false)
        }
    }

    private fun stopViewability() {
        if (viewabilityStarted) {
            SSPSDK.detachBannerViewability(adUnitId)
            viewabilityStarted = false
        }
    }

    private fun clearCreative() {
        omidSession?.finish()
        omidSession = null
        webView.loadDataWithBaseURL(null, "", "text/html", "UTF-8", null)
        imageView.setImageDrawable(null)
        webView.visibility = GONE
        imageView.visibility = GONE
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (loadedAd != null) post { startViewability() }
    }

    override fun onDetachedFromWindow() {
        cancelRefresh()
        stopViewability()
        super.onDetachedFromWindow()
    }

    private fun normalizeLoadParams(params: BannerLoadParams): BannerLoadParams {
        val code = params.placementCode?.trim().orEmpty().ifBlank { adUnitId }
        val context = params.placementContext?.trim().orEmpty().ifBlank { "banner" }
        return params.copy(placementCode = code, placementContext = context)
    }

    private fun scheduleRefresh(intervalSec: Int?) {
        cancelRefresh()
        val sec = intervalSec ?: return
        if (sec < 30) return
        refreshRunnable = Runnable { load() }.also {
            refreshHandler.postDelayed(it, sec * 1000L)
        }
    }

    private fun cancelRefresh() {
        refreshRunnable?.let { refreshHandler.removeCallbacks(it) }
        refreshRunnable = null
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (loadedAd != null && isAttachedToWindow) post { startViewability() }
    }

    fun destroy() {
        ++loadGeneration
        isLoading = false
        cancelRefresh()
        stopViewability()
        scope.cancel()
        clearCreative()
        loadedAd = null
        responseInfo = null
    }
}
