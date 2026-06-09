package com.dkmads.ssp

import android.content.Context
import android.view.ViewGroup
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

/**
 * ExoPlayer-backed surface for MP4 + HLS (`.m3u8`, `/hls/`) — parity with iOS `AVPlayer`.
 */
internal class DKMadsNativeVideoSurface(
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

    private val playerView = PlayerView(context).apply {
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }
    private val player: ExoPlayer = ExoPlayer.Builder(context).build()
    private var callbacks: Callbacks? = null
    private var prepared = false

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                Player.STATE_READY -> {
                    if (!prepared) {
                        prepared = true
                        callbacks?.onReady(player.duration.coerceAtLeast(0))
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
        }

        override fun onPlayerError(error: PlaybackException) {
            callbacks?.onError(error.message ?: "Video playback failed")
        }
    }

    init {
        playerView.player = player
        player.addListener(listener)
        parent.addView(playerView, 0)
    }

    fun play(url: String, autoplay: Boolean, muted: Boolean, callbacks: Callbacks) {
        this.callbacks = callbacks
        prepared = false
        playerView.visibility = android.view.View.VISIBLE
        player.volume = if (muted) 0f else 1f
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        player.playWhenReady = autoplay
    }

    fun setMuted(muted: Boolean) {
        player.volume = if (muted) 0f else 1f
    }

    fun currentPositionMs(): Long = player.currentPosition.coerceAtLeast(0)

    fun durationMs(): Long = player.duration.coerceAtLeast(0)

    fun isPlaying(): Boolean = player.isPlaying

    fun pause() {
        player.pause()
    }

    fun stop() {
        player.stop()
        player.clearMediaItems()
    }

    fun release() {
        player.removeListener(listener)
        player.release()
        parent.removeView(playerView)
        callbacks = null
        prepared = false
    }
}
