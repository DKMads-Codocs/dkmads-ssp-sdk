package com.dkmads.ssp

import android.content.res.Resources
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject

/**
 * MRAID 2.0 host callbacks. Defaults cover the common inline-banner case so a
 * view only overrides the commands it actually supports.
 */
interface DKMadsMraidHost {
    fun onMraidOpen(url: String)
    fun onMraidClose() {}
    fun onMraidExpand(url: String?) {}
    fun onMraidResize() {}
    fun onMraidUseCustomClose(useCustomClose: Boolean) {}
}

/**
 * Wires the shared MRAID 2.0 JS bridge into a creative [WebView]. Injects the
 * API before the page renders, signals ready/viewable state, and forwards
 * creative-initiated commands to the [host] on the main thread.
 */
class DKMadsMraidController(
    private val webView: WebView,
    private val placementType: String,
    private val host: DKMadsMraidHost,
) {
    private val main = Handler(Looper.getMainLooper())
    private var injected = false
    private var ready = false
    private var customClose = false

    fun attach() {
        webView.addJavascriptInterface(JsBridge(), "DKMadsMraidNative")
    }

    /** Inject the MRAID API. Call from `onPageStarted` so `window.mraid` exists early. */
    fun injectScript() {
        webView.evaluateJavascript(DKMadsMraidScript.JS, null)
        injected = true
    }

    /** Mark the creative ready (transition loading -> default). Call from `onPageFinished`. */
    fun notifyReady() {
        if (ready) return
        if (!injected) injectScript()
        ready = true
        eval("window.mraid && window.mraid._dkmadsSetReady('$placementType', ${geometryJson()})")
    }

    fun setViewable(viewable: Boolean) {
        eval("window.mraid && window.mraid._dkmadsSetViewable(${if (viewable) "true" else "false"})")
    }

    fun setState(state: String) {
        eval("window.mraid && window.mraid._dkmadsSetState('$state')")
    }

    fun updateGeometry() {
        eval("window.mraid && window.mraid._dkmadsSetGeometry(${geometryJson()})")
    }

    private fun eval(js: String) {
        main.post { runCatching { webView.evaluateJavascript(js, null) } }
    }

    private fun pxToDp(px: Int): Int {
        val density = Resources.getSystem().displayMetrics.density
        return if (density > 0) (px / density).toInt() else px
    }

    private fun geometryJson(): String {
        val metrics = Resources.getSystem().displayMetrics
        val screenW = pxToDp(metrics.widthPixels)
        val screenH = pxToDp(metrics.heightPixels)
        val w = if (webView.width > 0) pxToDp(webView.width) else screenW
        val h = if (webView.height > 0) pxToDp(webView.height) else screenH
        return JSONObject().apply {
            put("currentPosition", JSONObject().apply { put("x", 0); put("y", 0); put("width", w); put("height", h) })
            put("defaultPosition", JSONObject().apply { put("x", 0); put("y", 0); put("width", w); put("height", h) })
            put("maxSize", JSONObject().apply { put("width", screenW); put("height", screenH) })
            put("screenSize", JSONObject().apply { put("width", screenW); put("height", screenH) })
        }.toString()
    }

    private inner class JsBridge {
        @JavascriptInterface
        fun postMessage(json: String?) {
            val message = runCatching { JSONObject(json ?: "{}") }.getOrNull() ?: return
            val command = message.optString("command")
            val payload = message.optJSONObject("payload") ?: JSONObject()
            main.post { dispatch(command, payload) }
        }

        private fun dispatch(command: String, payload: JSONObject) {
            when (command) {
                "open" -> payload.optString("url").takeIf { it.isNotBlank() }?.let { host.onMraidOpen(it) }
                "close" -> {
                    setState(if (placementType == "interstitial") "hidden" else "default")
                    host.onMraidClose()
                }
                "expand" -> {
                    setState("expanded")
                    host.onMraidExpand(payload.optString("url").takeIf { it.isNotBlank() })
                }
                "resize" -> host.onMraidResize()
                "useCustomClose" -> {
                    customClose = payload.optBoolean("useCustomClose")
                    host.onMraidUseCustomClose(customClose)
                }
                "playVideo" -> payload.optString("url").takeIf { it.isNotBlank() }?.let { host.onMraidOpen(it) }
            }
        }
    }
}
