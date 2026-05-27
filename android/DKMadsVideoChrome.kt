package com.dkmads.ssp

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView

/** Premium video chrome helpers (no native media controller). */
object DKMadsVideoChrome {
    private const val CHROME_BG = 0x8C121212.toInt()
    private const val CHROME_BORDER = 0x38FFFFFF

    fun chromeButton(context: Context, label: String): Button = Button(context).apply {
        text = label
        setTextColor(Color.WHITE)
        textSize = 12f
        val density = context.resources.displayMetrics.density
        val hPad = (12 * density).toInt()
        val vPad = (7 * density).toInt()
        setPadding(hPad, vPad, hPad, vPad)
        background = pillBackground(context)
        contentDescription = label
    }

    fun muteIconButton(context: Context, muted: Boolean): ImageButton = ImageButton(context).apply {
        val density = context.resources.displayMetrics.density
        val size = (32 * density).toInt()
        setBackgroundDrawable(pillBackground(context))
        setImageResource(if (muted) android.R.drawable.ic_lock_silent_mode else android.R.drawable.ic_lock_silent_mode_off)
        scaleType = ImageView.ScaleType.CENTER_INSIDE
        setColorFilter(Color.WHITE)
        val pad = (6 * density).toInt()
        setPadding(pad, pad, pad, pad)
        contentDescription = if (muted) "Unmute advertisement" else "Mute advertisement"
        minimumWidth = size
        minimumHeight = size
    }

    fun updateMuteIcon(button: ImageButton, muted: Boolean) {
        button.setImageResource(if (muted) android.R.drawable.ic_lock_silent_mode else android.R.drawable.ic_lock_silent_mode_off)
        button.contentDescription = if (muted) "Unmute advertisement" else "Mute advertisement"
    }

    fun showsSkip(template: String?, skippable: Boolean): Boolean {
        if (!skippable) return false
        val t = template?.lowercase().orEmpty()
        return t != "video_outstream" && t != "display_video"
    }

    fun showsMute(template: String?): Boolean = true

    /** Instream replaces playing content — default sound on; outstream stays muted for autoplay policy. */
    fun defaultPlaybackMuted(unitFormat: String?, placementContext: String?, videoTemplate: String?): Boolean {
        val template = videoTemplate?.lowercase().orEmpty()
        val format = unitFormat?.lowercase().orEmpty()
        val ctx = placementContext?.lowercase().orEmpty()
        if (template == "video_instream" || format == "video_instream" || ctx == "instream") return false
        return true
    }

    fun showsProgress(template: String?): Boolean = true

    fun chromeBottomInsetPx(context: Context, hasProgress: Boolean = true): Int {
        val density = context.resources.displayMetrics.density
        val progress = if (hasProgress) 3f else 0f
        return ((10f + progress + 8f) * density).toInt()
    }

    private fun pillBackground(context: Context): GradientDrawable = GradientDrawable().apply {
        cornerRadius = 999f
        setColor(CHROME_BG)
        val stroke = (1 * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        setStroke(stroke, CHROME_BORDER)
    }
}
