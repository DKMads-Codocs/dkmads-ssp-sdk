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
object DKMadsClickThroughCta {
    fun attach(
        parent: FrameLayout,
        clickUrl: String?,
        onClickThrough: () -> Unit,
    ): Button? {
        val url = clickUrl?.trim().orEmpty()
        if (url.isBlank()) return null
        val density = parent.resources.displayMetrics.density
        val btn = Button(parent.context).apply {
            text = "Learn more"
            setTextColor(Color.WHITE)
            setBackgroundColor(0xFF1A73E8.toInt())
            contentDescription = "Advertisement — learn more"
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
        val lp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
        ).apply {
            val m = (12 * density).toInt()
            setMargins(m, m, m, m)
        }
        parent.addView(btn, lp)
        return btn
    }
}
