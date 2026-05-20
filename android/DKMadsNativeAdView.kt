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
import java.net.URL

/**
 * Native-format ad view: image and/or HTML `adm` (tag / rich native). Auto viewability when rendered.
 */
class DKMadsNativeAdView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
    var adUnitId: String = "",
    private var adWidth: Int = 300,
    private var adHeight: Int = 250,
) : FrameLayout(context, attrs, defStyleAttr) {

    interface Listener {
        fun onAdLoaded(view: DKMadsNativeAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(view: DKMadsNativeAdView, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onAdClicked(view: DKMadsNativeAdView) {}
        fun onAdImpression(view: DKMadsNativeAdView) {}
        fun onAdViewableImpression(view: DKMadsNativeAdView) {}
    }

    var listener: Listener? = null
    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val webView: WebView
    private val imageView: ImageView
    private var viewabilityStarted = false

    init {
        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            visibility = GONE
        }
        imageView = ImageView(context).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            visibility = GONE
            setOnClickListener { onClicked() }
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
        keyValues: Map<String, Any> = emptyMap(),
    ) {
        if (adUnitId.isBlank()) {
            listener?.onAdFailed(this, "adUnitId is required", null)
            return
        }
        stopViewability()
        clearCreative()
        scope.launch {
            val result = SSPSDK.loadAd(
                context = context,
                adUnitCode = adUnitId,
                format = AdFormat.NATIVE,
                sizes = listOf(adWidth to adHeight),
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill) {
                        listener?.onAdFailed(this@DKMadsNativeAdView, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    loadedAd = ad
                    render(ad)
                    listener?.onAdLoaded(this@DKMadsNativeAdView, ad, info)
                    listener?.onAdImpression(this@DKMadsNativeAdView)
                    post { startViewability() }
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsNativeAdView, err.message ?: "load failed", null)
                },
            )
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun render(ad: Ad) {
        if (ad.isHtml5 || ad.adm.isNotBlank()) {
            webView.visibility = VISIBLE
            imageView.visibility = GONE
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    post { startViewability() }
                }
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val uri = request?.url ?: return false
                    context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    onClicked()
                    return true
                }
            }
            if (ad.adm.isNotBlank()) {
                webView.loadDataWithBaseURL("https://ssp.dkmads.com", ad.adm, "text/html", "UTF-8", null)
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

    private fun onClicked() {
        val ad = loadedAd ?: return
        SSPSDK.recordAdClick(adUnitId, ad.id, campaignId = ad.campaignId, creativeId = ad.creativeId, dspSource = ad.dsp)
        listener?.onAdClicked(this)
        val click = ad.clickUrl
        if (click.isNotBlank()) {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(click)))
        }
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

    private fun clearCreative() {
        webView.loadDataWithBaseURL(null, "", "text/html", "UTF-8", null)
        imageView.setImageDrawable(null)
        webView.visibility = GONE
        imageView.visibility = GONE
    }

    fun destroy() {
        stopViewability()
        scope.cancel()
        clearCreative()
        loadedAd = null
        responseInfo = null
    }
}
