package com.dkmads.ssp

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout

/**
 * IAB-style click-through: explicit CTA only (not play/pause/skip on the video surface).
 */
enum class VideoCtaStyle {
    /** Instream — compact pill in bottom chrome row */
    DEFAULT,
    OUTSTREAM_BAR,
    REWARDED,
    END_CARD,
    BAR_BELOW,
}

object DKMadsClickThroughCta {
    fun attach(
        parent: FrameLayout,
        clickUrl: String?,
        style: VideoCtaStyle = VideoCtaStyle.DEFAULT,
        label: String = "Learn more",
        onClickThrough: () -> Unit,
        chromeRow: LinearLayout? = null,
    ): Button? {
        val url = clickUrl?.trim().orEmpty()
        if (url.isBlank()) return null
        val density = parent.resources.displayMetrics.density
        val btn = when (style) {
            VideoCtaStyle.DEFAULT, VideoCtaStyle.END_CARD -> DKMadsVideoChrome.compactCtaButton(parent.context, label)
            else -> createFullWidthCta(parent.context, style, label, density)
        }
        btn.contentDescription = "Advertisement — learn more"
        btn.setOnClickListener {
            onClickThrough()
            runCatching {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                if (parent.context !is Activity) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                parent.context.startActivity(intent)
            }
        }
        when (style) {
            VideoCtaStyle.DEFAULT -> {
                if (chromeRow != null) {
                    val lp = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        // Leave room for Skip on the trailing edge.
                        weight = 0f
                    }
                    btn.maxWidth = (parent.width.takeIf { it > 0 } ?: parent.resources.displayMetrics.widthPixels) / 2
                    btn.ellipsize = android.text.TextUtils.TruncateAt.END
                    btn.maxLines = 1
                    chromeRow.addView(btn, lp)
                } else {
                    val bottom = DKMadsVideoChrome.chromeBottomInsetPx(
                        parent.context,
                        hasProgress = true,
                    ) + (40 * density).toInt()
                    val lp = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                    ).apply {
                        val side = (48 * density).toInt()
                        setMargins(side, side, side + (72 * density).toInt(), bottom)
                    }
                    parent.addView(btn, lp)
                }
            }
            VideoCtaStyle.END_CARD -> {
                val lp = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                ).apply {
                    val m = (10 * density).toInt()
                    setMargins(m, m, m, m)
                }
                parent.addView(btn, lp)
            }
            VideoCtaStyle.OUTSTREAM_BAR -> {
                val lp = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM,
                )
                parent.addView(btn, lp)
            }
            VideoCtaStyle.REWARDED -> {
                val lp = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                ).apply {
                    val side = (16 * density).toInt()
                    val bottom = (20 * density).toInt()
                    setMargins(side, 0, side, bottom)
                }
                parent.addView(btn, lp)
            }
            VideoCtaStyle.BAR_BELOW -> {
                val lp = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM,
                ).apply {
                    val m = (8 * density).toInt()
                    setMargins(m, m, m, m)
                }
                parent.addView(btn, lp)
            }
        }
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

    private fun createFullWidthCta(
        context: android.content.Context,
        style: VideoCtaStyle,
        label: String,
        density: Float,
    ): Button = Button(context).apply {
        text = label.ifBlank { "Learn more" }
        setTextColor(Color.WHITE)
        isAllCaps = false
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        stateListAnimator = null
        elevation = 0f
        minHeight = 0
        minWidth = 0
        minimumHeight = 0
        minimumWidth = 0
        when (style) {
            VideoCtaStyle.REWARDED -> {
                textSize = 15f
                val hPad = (20 * density).toInt()
                val vPad = (12 * density).toInt()
                setPadding(hPad, vPad, hPad, vPad)
                background = roundedFill(context, 0xFF2563EB.toInt(), 8f * density)
            }
            VideoCtaStyle.OUTSTREAM_BAR, VideoCtaStyle.BAR_BELOW -> {
                textSize = 13f
                val hPad = (16 * density).toInt()
                val vPad = (10 * density).toInt()
                setPadding(hPad, vPad, hPad, vPad)
                background = roundedFill(context, 0xFF2563EB.toInt(), 0f)
            }
            else -> Unit
        }
    }

    private fun roundedFill(context: android.content.Context, color: Int, radiusPx: Float): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = radiusPx
            setColor(color)
        }
}
