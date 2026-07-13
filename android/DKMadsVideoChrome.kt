package com.dkmads.ssp

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Build
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout

/**
 * Premium video chrome (IMA / YouTube–aligned): 28–32dp glass controls, thin progress, no native scrubber.
 */
object DKMadsVideoChrome {
    private const val CHROME_BG = 0x8C121212.toInt()
    private const val CHROME_BORDER = 0x38FFFFFF
    private const val CTA_TOP = 0xFF3B82F6.toInt()
    private const val CTA_BOTTOM = 0xFF2563EB.toInt()

    const val ICON_DP = 28f
    const val CHROME_TEXT_SP = 11f
    const val CTA_TEXT_SP = 12f

    fun chromeButton(context: Context, label: String): Button = compactTextButton(context, label).apply {
        background = pillBackground(context)
    }

    fun compactCtaButton(context: Context, label: String): Button = compactTextButton(context, label).apply {
        textSize = CTA_TEXT_SP
        background = ctaPillBackground(context)
    }

    fun muteIconButton(context: Context, muted: Boolean): ImageButton = ImageButton(context).apply {
        val density = context.resources.displayMetrics.density
        val size = (ICON_DP * density).toInt()
        background = pillBackground(context)
        setImageDrawable(SpeakerIconDrawable(muted))
        scaleType = ImageView.ScaleType.CENTER_INSIDE
        val pad = (5 * density).toInt()
        setPadding(pad, pad, pad, pad)
        contentDescription = if (muted) "Unmute advertisement" else "Mute advertisement"
        minimumWidth = size
        minimumHeight = size
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            isForceDarkAllowed = false
        }
    }

    fun updateMuteIcon(button: ImageButton, muted: Boolean) {
        button.setImageDrawable(SpeakerIconDrawable(muted))
        button.contentDescription = if (muted) "Unmute advertisement" else "Mute advertisement"
    }

    fun showsSkip(template: String?, skippable: Boolean): Boolean {
        if (!skippable) return false
        val t = template?.lowercase().orEmpty()
        return t != "video_outstream" && t != "display_video"
    }

    fun showsMute(template: String?): Boolean = true

    fun defaultPlaybackMuted(unitFormat: String?, placementContext: String?, videoTemplate: String?): Boolean {
        return !isInstreamPlacement(unitFormat, placementContext, videoTemplate)
    }

    fun isInstreamPlacement(unitFormat: String?, placementContext: String?, videoTemplate: String?): Boolean {
        val template = videoTemplate?.lowercase().orEmpty()
        val format = unitFormat?.lowercase().orEmpty()
        val ctx = placementContext?.lowercase().orEmpty()
        if (template == "video_instream") return true
        if (format == "video_instream" || format.contains("instream")) return true
        if (ctx.contains("instream")) return true
        return false
    }

    fun showsProgress(template: String?): Boolean = true

    /** House/VAST ADM may already embed `.dkmads-chrome-*` — native chrome must not double up. */
    fun admHasPackagedChrome(adm: String?): Boolean {
        val lower = adm?.lowercase().orEmpty()
        return lower.contains("dkmads-chrome-skip")
            || lower.contains("dkmads-chrome-mute")
            || lower.contains("class=\"dkmads-chrome\"")
            || lower.contains("class='dkmads-chrome'")
            || lower.contains("dkmads-chrome-progress")
    }

    fun chromeBottomInsetPx(context: Context, hasProgress: Boolean = true): Int {
        val density = context.resources.displayMetrics.density
        val progress = if (hasProgress) 3f else 0f
        return ((11f + progress) * density).toInt()
    }

    fun chromeRowHeightPx(context: Context): Int {
        val density = context.resources.displayMetrics.density
        return (ICON_DP * density).toInt() + (6 * density).toInt()
    }

    /** Horizontal control row: [mute] — [CTA] — [skip]. */
    fun buildControlsRow(context: Context): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        val density = context.resources.displayMetrics.density
        val side = (12 * density).toInt()
        val top = (4 * density).toInt()
        setPadding(side, top, side, 0)
        gravity = android.view.Gravity.CENTER_VERTICAL
    }

    fun addWeightedSpacer(row: LinearLayout) {
        row.addView(
            android.view.View(row.context),
            LinearLayout.LayoutParams(0, 0, 1f),
        )
    }

    fun pillBackground(context: Context): GradientDrawable = GradientDrawable().apply {
        cornerRadius = 999f
        setColor(CHROME_BG)
        val stroke = (1 * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        setStroke(stroke, CHROME_BORDER)
    }

    private fun ctaPillBackground(context: Context): Drawable {
        val density = context.resources.displayMetrics.density
        val radius = 6f * density
        val fill = GradientDrawable().apply {
            cornerRadius = radius
            colors = intArrayOf(CTA_TOP, CTA_BOTTOM)
            orientation = GradientDrawable.Orientation.TOP_BOTTOM
        }
        val stroke = GradientDrawable().apply {
            cornerRadius = radius
            setStroke((1 * density).toInt().coerceAtLeast(1), 0x33FFFFFF)
            setColor(Color.TRANSPARENT)
        }
        return LayerDrawable(arrayOf(fill, stroke))
    }

    private fun compactTextButton(context: Context, label: String): Button = Button(context).apply {
        text = label
        setTextColor(Color.WHITE)
        textSize = CHROME_TEXT_SP
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        isAllCaps = false
        letterSpacing = 0.02f
        stateListAnimator = null
        elevation = 0f
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            translationZ = 0f
        }
        val density = context.resources.displayMetrics.density
        val hPad = (10 * density).toInt()
        val vPad = (5 * density).toInt()
        setPadding(hPad, vPad, hPad, vPad)
        minHeight = 0
        minWidth = 0
        minimumHeight = 0
        minimumWidth = 0
        contentDescription = label
    }

    /** Minimal speaker icon (no system lock glyphs). */
    private class SpeakerIconDrawable(private val muted: Boolean) : Drawable() {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        override fun draw(canvas: Canvas) {
            val w = bounds.width().toFloat()
            val h = bounds.height().toFloat()
            if (w <= 0f || h <= 0f) return
            paint.strokeWidth = (w * 0.09f).coerceAtLeast(1.5f)
            val cx = w * 0.38f
            val cy = h * 0.5f
            val body = w * 0.14f
            canvas.drawLine(cx - body, cy - body * 0.9f, cx - body, cy + body * 0.9f, paint)
            canvas.drawLine(cx - body, cy - body * 0.9f, cx + body * 0.2f, cy - body * 1.6f, paint)
            canvas.drawLine(cx + body * 0.2f, cy - body * 1.6f, cx + body * 0.2f, cy + body * 1.6f, paint)
            canvas.drawLine(cx - body, cy + body * 0.9f, cx + body * 0.2f, cy + body * 1.6f, paint)
            if (!muted) {
                canvas.drawArc(
                    cx + body * 0.35f,
                    cy - body * 1.1f,
                    cx + body * 2.4f,
                    cy + body * 1.1f,
                    -58f,
                    116f,
                    false,
                    paint,
                )
                canvas.drawArc(
                    cx + body * 0.55f,
                    cy - body * 1.7f,
                    cx + body * 3.2f,
                    cy + body * 1.7f,
                    -52f,
                    104f,
                    false,
                    paint,
                )
            } else {
                canvas.drawLine(w * 0.62f, h * 0.28f, w * 0.82f, h * 0.72f, paint)
                canvas.drawLine(w * 0.82f, h * 0.28f, w * 0.62f, h * 0.72f, paint)
            }
        }

        override fun setAlpha(alpha: Int) {
            paint.alpha = alpha
        }

        override fun setColorFilter(colorFilter: ColorFilter?) {
            paint.colorFilter = colorFilter
        }

        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }
}
