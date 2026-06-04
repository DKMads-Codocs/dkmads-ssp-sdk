package com.dkmads.ssp

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.FrameLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class DKMadsAdInspectorActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Ad Inspector"

        val textView = TextView(this).apply {
            typeface = android.graphics.Typeface.MONOSPACE
            textSize = 12f
            setPadding(24, 24, 24, 24)
            text = buildInspectorText()
            setTextIsSelectable(true)
        }

        val scroll = ScrollView(this).apply {
            addView(textView)
        }

        val root = FrameLayout(this).apply {
            addView(
                scroll,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
        setContentView(root)
    }

    private fun buildInspectorText(): String {
        val diag = SSPSDK.lastBidDiagnostics
        if (diag == null) {
            return """
                No bid recorded yet.

                1. Enable debug or useTestAds in SSPSDK.Config
                2. Load an ad (banner, interstitial, or app open)
                3. Reopen Ad Inspector

                Tip: Match dashboard ad unit format/size to your creative.
            """.trimIndent()
        }
        return buildString {
            append(diag.summaryText)
            appendLine()
            appendLine("---")
            append(diag.troubleshootingHint)
            diag.errorMessage?.takeIf { it.isNotBlank() }?.let {
                appendLine()
                appendLine("---")
                appendLine("last_error: $it")
            }
        }
    }

    companion object {
        fun launch(context: Context) {
            context.startActivity(
                Intent(context, DKMadsAdInspectorActivity::class.java).apply {
                    if (context !is Activity) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }

        fun copyRequestId(context: Context): Boolean {
            val id = SSPSDK.lastBidDiagnostics?.requestId ?: return false
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("request_id", id))
            Toast.makeText(context, "Copied request_id", Toast.LENGTH_SHORT).show()
            return true
        }
    }
}
