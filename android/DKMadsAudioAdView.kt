package com.dkmads.ssp

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.util.AttributeSet
import android.widget.FrameLayout
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Loads and plays audio creatives (`audio_url` or audio `adm`). Use with dashboard format `audio`.
 */
class DKMadsAudioAdView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
    var adUnitId: String = "",
) : FrameLayout(context, attrs, defStyleAttr) {

    interface Listener {
        fun onAdLoaded(view: DKMadsAudioAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {}
        fun onAdFailed(view: DKMadsAudioAdView, message: String, responseInfo: DKMadsResponseInfo?) {}
        fun onPlaybackStarted(view: DKMadsAudioAdView) {}
        fun onPlaybackComplete(view: DKMadsAudioAdView) {}
        fun onAdClicked(view: DKMadsAudioAdView) {}
        fun onAdImpression(view: DKMadsAudioAdView) {}
    }

    var listener: Listener? = null
    var autoplay: Boolean = true

    var loadedAd: Ad? = null
        private set
    var responseInfo: DKMadsResponseInfo? = null
        private set

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var mediaPlayer: MediaPlayer? = null

    fun load(
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
                format = AdFormat.AUDIO,
                sizes = emptyList(),
                placementCode = placementCode,
                placementContext = placementContext,
                keyValues = keyValues,
            )
            result.fold(
                onSuccess = { ad ->
                    val info = DKMadsResponseInfo.from(ad)
                    responseInfo = info
                    if (!ad.hasFill || !ad.isAudio) {
                        listener?.onAdFailed(this@DKMadsAudioAdView, ad.reason ?: "no_fill", info)
                        return@fold
                    }
                    val url = resolveAudioUrl(ad)
                    if (url.isBlank()) {
                        listener?.onAdFailed(this@DKMadsAudioAdView, "Audio fill missing audio_url", info)
                        return@fold
                    }
                    loadedAd = ad
                    listener?.onAdLoaded(this@DKMadsAudioAdView, ad, info)
                    listener?.onAdImpression(this@DKMadsAudioAdView)
                    startPlayback(url)
                },
                onFailure = { err ->
                    listener?.onAdFailed(this@DKMadsAudioAdView, err.message ?: "load failed", null)
                },
            )
        }
    }

    fun playLoadedAd() {
        val ad = loadedAd ?: return
        val url = resolveAudioUrl(ad)
        if (url.isNotBlank()) startPlayback(url)
    }

    fun openClickUrl() {
        val ad = loadedAd ?: return
        SSPSDK.recordAdClick(adUnitId, ad.id, campaignId = ad.campaignId, creativeId = ad.creativeId, dspSource = ad.dsp)
        listener?.onAdClicked(this)
        val click = ad.clickUrl
        if (click.isNotBlank()) {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(click)))
        }
    }

    private fun resolveAudioUrl(ad: Ad): String {
        if (ad.audioUrl.isNotBlank()) return ad.audioUrl
        val src = Regex("""src=["']([^"']+)["']""", RegexOption.IGNORE_CASE).find(ad.adm)?.groupValues?.getOrNull(1)
        return src?.trim().orEmpty()
    }

    private fun startPlayback(url: String) {
        stopPlayback()
        try {
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(url)
                setOnPreparedListener {
                    if (autoplay) {
                        start()
                        listener?.onPlaybackStarted(this@DKMadsAudioAdView)
                    }
                }
                setOnCompletionListener {
                    listener?.onPlaybackComplete(this@DKMadsAudioAdView)
                }
                setOnErrorListener { _, _, _ ->
                    listener?.onAdFailed(this@DKMadsAudioAdView, "Audio playback failed", responseInfo)
                    true
                }
                prepareAsync()
            }
            mediaPlayer = player
        } catch (e: Exception) {
            listener?.onAdFailed(this, e.message ?: "playback failed", responseInfo)
        }
    }

    fun stopPlayback() {
        mediaPlayer?.runCatching {
            stop()
            release()
        }
        mediaPlayer = null
    }

    fun destroy() {
        stopPlayback()
        scope.cancel()
        loadedAd = null
        responseInfo = null
    }
}
