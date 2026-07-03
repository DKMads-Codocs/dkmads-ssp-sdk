package com.dkmads.ssp

import android.content.Context
import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.view.View
import android.view.ViewGroup
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

/**
 * Dual ExoPlayer surface for `contain_blur` — zoomed blurred backdrop + centered main video.
 */
internal class DKMadsVideoBlurNativeSurface(
    context: Context,
    private val parent: ViewGroup,
) {
    interface Callbacks {
        fun onReady(durationMs: Long) {}
        fun onPlaybackStarted() {}
        fun onBuffering(buffering: Boolean) {}
        fun onComplete() {}
        fun onError(message: String) {}
    }

    private val backdropHost = android.widget.FrameLayout(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        clipChildren = true
    }
    private val backdropView = PlayerView(context).apply {
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
        setShutterBackgroundColor(Color.TRANSPARENT)
        scaleX = 1.12f
        scaleY = 1.12f
        layoutParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.Gravity.CENTER,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setRenderEffect(RenderEffect.createBlurEffect(48f, 48f, Shader.TileMode.CLAMP))
        }
        alpha = 0.92f
    }
    private val backdropDim = android.view.View(context).apply {
        setBackgroundColor(Color.argb(72, 0, 0, 0))
        layoutParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        visibility = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) View.GONE else android.view.View.VISIBLE
    }
    private val foregroundView = PlayerView(context).apply {
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        setShutterBackgroundColor(Color.TRANSPARENT)
        setBackgroundColor(Color.TRANSPARENT)
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }
    private val backdropPlayer: ExoPlayer = ExoPlayer.Builder(context).build()
    private val foregroundPlayer: ExoPlayer = ExoPlayer.Builder(context).build()
    private var callbacks: Callbacks? = null
    private var prepared = false

    private val foregroundListener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                Player.STATE_READY -> {
                    if (!prepared) {
                        prepared = true
                        callbacks?.onReady(foregroundPlayer.duration.coerceAtLeast(0))
                    }
                    callbacks?.onBuffering(false)
                }
                Player.STATE_BUFFERING -> callbacks?.onBuffering(true)
                Player.STATE_ENDED -> callbacks?.onComplete()
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying && prepared) {
                callbacks?.onPlaybackStarted()
            }
            backdropPlayer.playWhenReady = isPlaying
        }

        override fun onPlayerError(error: PlaybackException) {
            callbacks?.onError(error.message ?: "Video playback failed")
        }
    }

    private val syncListener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            if (state == Player.STATE_READY) {
                val pos = foregroundPlayer.currentPosition
                if (kotlin.math.abs(backdropPlayer.currentPosition - pos) > 350) {
                    backdropPlayer.seekTo(pos)
                }
            }
        }
    }

    init {
        backdropHost.addView(backdropView)
        backdropHost.addView(backdropDim)
        parent.addView(backdropHost, 0)
        parent.addView(foregroundView, 1)
        backdropView.player = backdropPlayer
        foregroundView.player = foregroundPlayer
        foregroundPlayer.addListener(foregroundListener)
        foregroundPlayer.addListener(syncListener)
        backdropPlayer.volume = 0f
    }

    fun play(url: String, autoplay: Boolean, muted: Boolean, callbacks: Callbacks) {
        this.callbacks = callbacks
        prepared = false
        val item = MediaItem.fromUri(url)
        backdropPlayer.setMediaItem(item)
        foregroundPlayer.setMediaItem(item)
        foregroundPlayer.volume = if (muted) 0f else 1f
        backdropPlayer.prepare()
        foregroundPlayer.prepare()
        backdropPlayer.playWhenReady = autoplay
        foregroundPlayer.playWhenReady = autoplay
    }

    fun setMuted(muted: Boolean) {
        foregroundPlayer.volume = if (muted) 0f else 1f
    }

    fun currentPositionMs(): Long = foregroundPlayer.currentPosition.coerceAtLeast(0)

    fun durationMs(): Long = foregroundPlayer.duration.coerceAtLeast(0)

    fun isPlaying(): Boolean = foregroundPlayer.isPlaying

    fun pause() {
        foregroundPlayer.pause()
        backdropPlayer.pause()
    }

    fun stop() {
        foregroundPlayer.stop()
        foregroundPlayer.clearMediaItems()
        backdropPlayer.stop()
        backdropPlayer.clearMediaItems()
    }

    fun release() {
        foregroundPlayer.removeListener(foregroundListener)
        foregroundPlayer.removeListener(syncListener)
        foregroundPlayer.release()
        backdropPlayer.release()
        parent.removeView(backdropHost)
        parent.removeView(foregroundView)
        callbacks = null
        prepared = false
    }
}
