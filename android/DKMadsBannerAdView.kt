package com.dkmads.ssp

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.AttributeSet
import android.view.View
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView
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
    )
    private var lastLoadParams: BannerLoadParams? = null
    private val webView: WebView
    private val imageView: ImageView
    private var viewabilityStarted = false

    init {
        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            visibility = GONE
        }
        imageView = ImageView(context).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = GONE
            setOnClickListener { onBannerClicked() }
        }
        addView(webView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(imageView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    fun setAdSize(width: Int, height: Int) {
        adWidth = width
        adHeight = height
        layoutParams = layoutParams?.apply {
            this.width = width
            this.height = height
        } ?: LayoutParams(width, height)
    }

    fun load(
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any>? = null,
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        val resolved = BannerLoadParams(
            placementCode = placementCode ?: lastLoadParams?.placementCode,
            placementContext = placementContext ?: lastLoadParams?.placementContext,
            keyValues = keyValues ?: lastLoadParams?.keyValues ?: emptyMap(),
        )
        lastLoadParams = resolved
        stopViewability()
        clearCreative()
        val slot = DKMadsBannerCreativeLayout.effectiveSlotSize(adWidth, adHeight, width, height)
        if (width > 0 && height > 0 && (slot.first != adWidth || slot.second != adHeight)) {
            adWidth = slot.first
            adHeight = slot.second
        }
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.BANNER,
                sizes = listOf(slot),
                placementCode = resolved.placementCode,
                placementContext = resolved.placementContext,
                keyValues = resolved.keyValues,
            )
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
        val slot = DKMadsBannerCreativeLayout.effectiveSlotSize(adWidth, adHeight, width, height)
        if (ad.isHtml5 || ad.adm.isNotBlank()) {
            webView.visibility = VISIBLE
            imageView.visibility = GONE
            @SuppressLint("SetJavaScriptEnabled")
            webView.settings.javaScriptEnabled = true
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    view?.evaluateJavascript(DKMadsBannerCreativeLayout.VIEWPORT_INJECTION_SCRIPT, null)
                    post { startViewability() }
                }
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val uri = request?.url ?: return false
                    if (!ClickThroughNavigation.matches(ad.clickUrl, uri.toString())) return false
                    onBannerClicked(uri)
                    return true
                }
            }
            if (ad.adm.isNotBlank()) {
                webView.loadDataWithBaseURL(
                    "https://ssp.dkmads.com",
                    DKMadsBannerCreativeLayout.htmlForBanner(ad.adm, slot.first, slot.second),
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
                    post { startViewability() }
                }
            }
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
            onViewable = { listener?.onAdViewableImpression(this@DKMadsBannerAdView) },
        )
    }

    private fun stopViewability() {
        if (viewabilityStarted) {
            SSPSDK.detachBannerViewability(adUnitId)
            viewabilityStarted = false
        }
    }

    private fun clearCreative() {
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
        cancelRefresh()
        stopViewability()
        scope.cancel()
        clearCreative()
        loadedAd = null
        responseInfo = null
    }
}
