package com.dkmads.ssp

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout

/**
 * IAB-style click-through: explicit CTA only (not play/pause/skip on the video surface).
 */
enum class VideoCtaStyle {
    /** Instream / default — compact pill, bottom center */
    DEFAULT,
    /** Outstream — full-width bar at bottom of placement */
    OUTSTREAM_BAR,
    /** Rewarded / splash / interstitial video — large primary button */
    REWARDED,
    /** Overlay on video (end-card style) */
    END_CARD,
    /** Full-width bar below video (non-outstream) */
    BAR_BELOW,
}

object DKMadsClickThroughCta {
    fun attach(
        parent: FrameLayout,
        clickUrl: String?,
        style: VideoCtaStyle = VideoCtaStyle.DEFAULT,
        label: String = "Learn more",
        onClickThrough: () -> Unit,
    ): Button? {
        val url = clickUrl?.trim().orEmpty()
        if (url.isBlank()) return null
        val density = parent.resources.displayMetrics.density
        val btn = Button(parent.context).apply {
            text = label.ifBlank { "Learn more" }
            setTextColor(Color.WHITE)
            setBackgroundColor(0xFF1A73E8.toInt())
            contentDescription = "Advertisement — learn more"
            when (style) {
                VideoCtaStyle.REWARDED -> {
                    textSize = 16f
                    val hPad = (20 * density).toInt()
                    val vPad = (14 * density).toInt()
                    setPadding(hPad, vPad, hPad, vPad)
                }
                VideoCtaStyle.OUTSTREAM_BAR -> {
                    textSize = 14f
                    val hPad = (16 * density).toInt()
                    val vPad = (12 * density).toInt()
                    setPadding(hPad, vPad, hPad, vPad)
                }
                VideoCtaStyle.DEFAULT, VideoCtaStyle.END_CARD -> {
                    textSize = 14f
                    val hPad = (16 * density).toInt()
                    val vPad = (8 * density).toInt()
                    setPadding(hPad, vPad, hPad, vPad)
                }
                VideoCtaStyle.BAR_BELOW -> {
                    textSize = 14f
                    val hPad = (16 * density).toInt()
                    val vPad = (12 * density).toInt()
                    setPadding(hPad, vPad, hPad, vPad)
                }
            }
            if (style == VideoCtaStyle.END_CARD) {
                setBackgroundColor(0xEB1A73E8.toInt())
            }
            setOnClickListener {
                onClickThrough()
                runCatching {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    if (parent.context !is Activity) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    parent.context.startActivity(intent)
                }
            }
        }
        val lp = when (style) {
            VideoCtaStyle.OUTSTREAM_BAR -> FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ).apply {
                val m = (0 * density).toInt()
                setMargins(m, m, m, m)
            }
            VideoCtaStyle.REWARDED -> FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                val side = (16 * density).toInt()
                val bottom = (20 * density).toInt()
                setMargins(side, 0, side, bottom)
            }
            VideoCtaStyle.END_CARD -> FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                val m = (10 * density).toInt()
                setMargins(m, m, m, m)
            }
            VideoCtaStyle.BAR_BELOW -> FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ).apply {
                val m = (8 * density).toInt()
                setMargins(m, m, m, m)
            }
            VideoCtaStyle.DEFAULT -> FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                val m = (12 * density).toInt()
                setMargins(m, m, m, m)
            }
        }
        parent.addView(btn, lp)
        return btn
    }

    fun styleForTemplate(template: String?): VideoCtaStyle = when (template?.lowercase()) {
        "video_outstream" -> VideoCtaStyle.OUTSTREAM_BAR
        "rewarded", "splash" -> VideoCtaStyle.REWARDED
        else -> VideoCtaStyle.DEFAULT
    }

    fun styleForAd(template: String?, ctaPosition: String?): VideoCtaStyle {
        when (ctaPosition?.lowercase()) {
            "end_card" -> return VideoCtaStyle.END_CARD
            "bar_below" -> return if (template?.lowercase() == "video_outstream") {
                VideoCtaStyle.OUTSTREAM_BAR
            } else {
                VideoCtaStyle.BAR_BELOW
            }
        }
        return styleForTemplate(template)
    }
}
