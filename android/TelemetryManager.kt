package com.dkmads.ssp

import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Telemetry Manager — built-in viewability, quartile & fraud detection.
 * Flushes to `${baseUrl}/v1/events` with the property integrationKey as X-Integration-Key.
 */
class TelemetryManager {

    private var config: Config? = null
    private var appContext: android.content.Context? = null
    private var consent: ConsentState = ConsentState()
    private var identityProvider: (() -> Map<String, String?>)? = null

    fun setApplicationContext(context: android.content.Context) {
        appContext = context.applicationContext
    }

    fun setIdentityProvider(provider: () -> Map<String, String?>) {
        identityProvider = provider
    }
    private val buffer = ConcurrentLinkedQueue<JSONObject>()
    private val pending = ConcurrentLinkedQueue<JSONObject>()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val handler = Handler(Looper.getMainLooper())
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private val viewabilityObservers = mutableMapOf<String, ViewabilityObserver>()
    private val videoTrackers = mutableMapOf<String, VideoTracker>()

    fun configure(config: Config) {
        this.config = config
        flushPendingEvents()
        startFlushTimer()
    }

    fun setConsent(consent: ConsentState) {
        this.consent = consent
    }

    // --- Event tracking --------------------------------------------------

    fun trackEvent(type: String, data: Map<String, Any?> = emptyMap()) {
            val cfg = config
            val event = JSONObject().apply {
            put("type", type)
            put("timestamp", dateFormat.format(Date()))
            put("os", "android")
            put("device_type", "mobile")
            put("sdk_version", SDK_VERSION)
            put("consent_string", consent.consentString ?: JSONObject.NULL)
            put("gpp_string", consent.gppString ?: JSONObject.NULL)
            put("gpp_sid", consent.gppSid ?: JSONObject.NULL)
            put("gdpr_applies", consent.gdpr)
            put("us_privacy_string", if (consent.ccpa) "1YYY" else "1---")
            identityProvider?.invoke()?.forEach { (k, v) ->
                if (!v.isNullOrBlank()) put(k, v)
            }
            data.forEach { (k, v) -> put(k, v ?: JSONObject.NULL) }
        }
        if (cfg == null) {
            pending.add(event)
        } else {
            buffer.add(event)
            if (buffer.size >= MAX_BUFFER) flushEvents()
        }
    }

    // --- Viewability -----------------------------------------------------

    fun trackViewability(
        adUnitId: String,
        container: View,
        threshold: Float = 0.5f,
        minExposureTimeMs: Long = 1000,
        extra: Map<String, Any?> = emptyMap(),
        onViewable: (() -> Unit)? = null,
    ) {
        stopViewabilityTracking(adUnitId)

        // Fraud detection first (emits an event if anomalies present).
        detectFraudSignals(adUnitId, container, extra)

        trackEvent(
            "impression",
            extra + mapOf("ad_unit_id" to adUnitId)
        )
        trackEvent(
            "measurable_impression",
            extra + mapOf("ad_unit_id" to adUnitId)
        )

        val observer = ViewabilityObserver(
            adUnitId, container, threshold, minExposureTimeMs
        ) { data ->
            trackEvent(
                "viewable_impression",
                extra + mapOf(
                    "ad_unit_id" to adUnitId,
                    "metadata" to mapOf(
                        "visible_percent" to (data["visible_percent"] ?: 0),
                        "exposure_time_ms" to (data["exposure_time_ms"] ?: 0),
                        "viewability_bucket" to (data["viewability_bucket"] ?: ""),
                        "viewability_status" to "viewable",
                        "threshold" to "IAB_STANDARD"
                    )
                )
            )
            onViewable?.invoke()
        }
        viewabilityObservers[adUnitId] = observer
        observer.start()
    }

    fun stopViewabilityTracking(adUnitId: String) {
        viewabilityObservers.remove(adUnitId)?.stop()
    }

    // --- Video ----------------------------------------------------------

    fun trackVideoAd(
        adUnitId: String,
        campaignId: String?,
        creativeId: String?,
        containerView: View,
        durationMsProvider: () -> Long,
        currentPositionMsProvider: () -> Long,
        isPlayingProvider: () -> Boolean,
        isMutedProvider: () -> Boolean = { false },
        skippable: Boolean? = null,
        eventListener: ((String, Map<String, Any?>) -> Unit)? = null
    ): VideoTracker {
        stopVideoTracking(adUnitId)
        val tracker = VideoTracker(
            adUnitId = adUnitId,
            campaignId = campaignId,
            creativeId = creativeId,
            containerView = containerView,
            durationMsProvider = durationMsProvider,
            positionMsProvider = currentPositionMsProvider,
            isPlayingProvider = isPlayingProvider,
            isMutedProvider = isMutedProvider,
            skippable = skippable
        )
        tracker.onVideoStart = { meta -> trackEvent("video_start", meta); eventListener?.invoke("video_start", meta) }
        tracker.onQuartileReached = { q, meta -> trackEvent("video_$q", meta); eventListener?.invoke("video_$q", meta) }
        tracker.onVideoComplete = { meta -> trackEvent("video_100", meta); eventListener?.invoke("video_100", meta) }
        tracker.onVideoViewable = { meta -> trackEvent("video_viewable", meta); eventListener?.invoke("video_viewable", meta) }
        tracker.onVideoPaused = { meta -> trackEvent("video_pause", meta); eventListener?.invoke("video_pause", meta) }
        tracker.onVideoResumed = { meta -> trackEvent("video_resume", meta); eventListener?.invoke("video_resume", meta) }
        tracker.onVideoSkipped = { meta -> trackEvent("video_skip", meta); eventListener?.invoke("video_skip", meta) }
        tracker.onVideoMuted = { meta -> trackEvent("video_mute", meta); eventListener?.invoke("video_mute", meta) }
        tracker.onVideoUnmuted = { meta -> trackEvent("video_unmute", meta); eventListener?.invoke("video_unmute", meta) }
        tracker.onVideoPlaybackError = { meta -> trackEvent("video_error", meta); eventListener?.invoke("video_error", meta) }
        videoTrackers[adUnitId] = tracker
        tracker.start()
        return tracker
    }

    fun stopVideoTracking(adUnitId: String) {
        videoTrackers.remove(adUnitId)?.stop()
    }

    // --- Fraud detection -------------------------------------------------

    fun detectFraudSignals(adUnitId: String, view: View, extra: Map<String, Any?> = emptyMap()): List<Map<String, Any>> {
        val signals = mutableListOf<Map<String, Any>>()
        if (view.width < 50 || view.height < 50) {
            signals.add(mapOf(
                "type" to "tiny_container",
                "severity" to "medium",
                "confidence" to 0.8,
                "details" to mapOf("width" to view.width, "height" to view.height)
            ))
        }
        if (!view.isShown || view.visibility != View.VISIBLE) {
            signals.add(mapOf(
                "type" to "hidden_placement",
                "severity" to "high",
                "confidence" to 0.9
            ))
        }
        if (view.alpha == 0f) {
            signals.add(mapOf(
                "type" to "zero_opacity",
                "severity" to "high",
                "confidence" to 0.95
            ))
        }
        val location = IntArray(2)
        view.getLocationOnScreen(location)
        if (location[0] < -1000 || location[1] < -1000) {
            signals.add(mapOf(
                "type" to "offscreen_placement",
                "severity" to "high",
                "confidence" to 0.85
            ))
        }
        if (signals.isNotEmpty()) {
            val severity = signals.maxByOrNull {
                when (it["severity"]) {
                    "critical" -> 4; "high" -> 3; "medium" -> 2; else -> 1
                }
            }?.get("severity") ?: "low"
            trackEvent(
                "fraud_detection",
                extra + mapOf(
                    "ad_unit_id" to adUnitId,
                    "metadata" to mapOf(
                        "signals" to signals,
                        "severity" to severity
                    )
                )
            )
        }
        return signals
    }

    // --- Flush lifecycle -------------------------------------------------

    private fun startFlushTimer() {
        handler.postDelayed(object : Runnable {
            override fun run() {
                flushEvents()
                handler.postDelayed(this, FLUSH_INTERVAL_MS)
            }
        }, FLUSH_INTERVAL_MS)
    }

    fun flushEvents() {
        val cfg = config ?: return
        if (buffer.isEmpty()) return
        val events = mutableListOf<JSONObject>()
        while (buffer.isNotEmpty()) {
            buffer.poll()?.let { events.add(it) }
        }
        scope.launch {
            try {
                val url = URL("${publicApiBase(cfg.baseUrl)}/v1/events")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("X-Integration-Key", cfg.integrationKey)
                conn.doOutput = true
                val body = JSONObject().apply { put("events", JSONArray(events)) }
                OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
                val code = conn.responseCode
                appContext?.let {
                    PlatformIdentity.saveFromHeader(it, conn.getHeaderField("X-DKMads-Platform-Uid"))
                }
                conn.disconnect()
                if (code >= 400) {
                    events.forEach { buffer.add(it) }
                    Log.w("Telemetry", "flush failed http=$code, re-queued ${events.size}")
                }
            } catch (e: Exception) {
                events.forEach { buffer.add(it) }
                Log.e("Telemetry", "flush failed", e)
            }
        }
    }

    private fun flushPendingEvents() {
        while (pending.isNotEmpty()) {
            pending.poll()?.let { buffer.add(it) }
        }
        flushEvents()
    }

    private fun publicApiBase(baseUrl: String): String {
        var normalized = baseUrl.trim().trimEnd('/')
        if (normalized.endsWith("/api")) {
            normalized = normalized.removeSuffix("/api")
        }
        return normalized
    }

    companion object {
        val shared = TelemetryManager()
        private const val MAX_BUFFER = 50
        private const val FLUSH_INTERVAL_MS = 2000L
    }
}

// --- Data classes ------------------------------------------------------------

// --- Viewability Observer (continuous exposure) ------------------------------

class ViewabilityObserver(
    private val adUnitId: String,
    private val container: View,
    private val threshold: Float,
    private val minExposureTimeMs: Long,
    private val onViewable: (Map<String, Any>) -> Unit
) {
    private var runStart: Long = 0
    private var accumExposure: Long = 0
    private var isViewable = false
    private var preDrawListener: ViewTreeObserver.OnPreDrawListener? = null

    fun start() {
        preDrawListener = ViewTreeObserver.OnPreDrawListener {
            tick()
            true
        }
        container.viewTreeObserver.addOnPreDrawListener(preDrawListener)
    }

    fun stop() {
        preDrawListener?.let {
            if (container.viewTreeObserver.isAlive) {
                container.viewTreeObserver.removeOnPreDrawListener(it)
            }
        }
        preDrawListener = null
    }

    private fun tick() {
        if (isViewable) return
        val visibleRect = Rect()
        val isGlobal = container.getGlobalVisibleRect(visibleRect)
        val now = System.currentTimeMillis()
        val effectiveVisible =
            isGlobal && container.isShown && container.alpha > 0.1f
        val totalArea = container.width.toLong() * container.height.toLong()
        val visibleArea = visibleRect.width().toLong() * visibleRect.height().toLong()
        val ratio = if (totalArea > 0) visibleArea.toFloat() / totalArea.toFloat() else 0f

        if (effectiveVisible && ratio >= threshold) {
            if (runStart == 0L) runStart = now
            accumExposure += now - runStart
            runStart = now
            if (accumExposure >= minExposureTimeMs && !isViewable) {
                isViewable = true
                onViewable(
                    mapOf(
                        "visible_percent" to (ratio * 100).toDouble(),
                        "exposure_time_ms" to accumExposure,
                        "viewability_bucket" to bucketFor(ratio)
                    )
                )
                stop()
            }
        } else {
            runStart = 0L
        }
    }

    private fun bucketFor(ratio: Float): String {
        val p = ratio * 100
        return when {
            p < 25 -> "0_25"
            p < 50 -> "25_50"
            p < 75 -> "50_75"
            else -> "75_100"
        }
    }
}

// --- Video Tracker -----------------------------------------------------------

class VideoTracker(
    private val adUnitId: String,
    private val campaignId: String?,
    private val creativeId: String?,
    private val containerView: View,
    private val durationMsProvider: () -> Long,
    private val positionMsProvider: () -> Long,
    private val isPlayingProvider: () -> Boolean,
    private val isMutedProvider: () -> Boolean,
    private val skippable: Boolean?
) {
    private val handler = Handler(Looper.getMainLooper())
    private val reached = mutableSetOf<Int>()
    private var started = false
    private var completed = false
    private var skipped = false
    private var wasPlaying = false
    private var wasMuted = false
    private var lastPositionMs: Long = 0

    private var videoViewAccum: Long = 0
    private var videoRunStart: Long = 0
    private var videoViewableFired = false

    var onVideoStart: ((Map<String, Any?>) -> Unit)? = null
    var onQuartileReached: ((Int, Map<String, Any?>) -> Unit)? = null
    var onVideoComplete: ((Map<String, Any?>) -> Unit)? = null
    var onVideoViewable: ((Map<String, Any?>) -> Unit)? = null
    var onVideoPaused: ((Map<String, Any?>) -> Unit)? = null
    var onVideoResumed: ((Map<String, Any?>) -> Unit)? = null
    var onVideoSkipped: ((Map<String, Any?>) -> Unit)? = null
    var onVideoMuted: ((Map<String, Any?>) -> Unit)? = null
    var onVideoUnmuted: ((Map<String, Any?>) -> Unit)? = null
    var onVideoPlaybackError: ((Map<String, Any?>) -> Unit)? = null

    private val tickRunnable = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, 250)
        }
    }

    fun start() {
        stop()
        handler.post(tickRunnable)
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
    }

    private fun baseMeta(): Map<String, Any?> = mapOf(
        "ad_unit_id" to adUnitId,
        "campaign_id" to campaignId,
        "creative_id" to creativeId,
        "metadata" to mapOf<String, Any?>(
            "video_duration_ms" to durationMsProvider(),
            "video_current_time_ms" to positionMsProvider(),
            "autoplay" to isPlayingProvider(),
            "muted" to isMutedProvider(),
            "skippable" to skippable
        )
    )

    private fun tick() {
        val dur = durationMsProvider()
        if (dur <= 0) {
            val meta = baseMeta().toMutableMap()
            val m = (meta["metadata"] as Map<*, *>).toMutableMap()
            m["error_message"] = "invalid_duration"
            meta["metadata"] = m
            @Suppress("UNCHECKED_CAST")
            onVideoPlaybackError?.invoke(meta as Map<String, Any?>)
            return
        }
        val pos = positionMsProvider()
        val pct = (pos.toDouble() / dur.toDouble()).coerceIn(0.0, 1.0)
        val playing = isPlayingProvider()
        if (!started && playing) {
            started = true
            onVideoStart?.invoke(baseMeta())
        }
        if (wasPlaying && !playing && !completed) {
            onVideoPaused?.invoke(baseMeta())
        } else if (!wasPlaying && playing && started && !completed) {
            onVideoResumed?.invoke(baseMeta())
        }
        val muted = isMutedProvider()
        if (started && !completed && wasMuted != muted) {
            if (muted) onVideoMuted?.invoke(baseMeta()) else onVideoUnmuted?.invoke(baseMeta())
        }
        if (skippable == true && started && !completed && !skipped) {
            val jumpedToEnd = (pos - lastPositionMs) > 3000 && pct >= 0.9
            if (jumpedToEnd) {
                skipped = true
                onVideoSkipped?.invoke(baseMeta())
            }
        }
        for (q in listOf(25, 50, 75)) {
            if (!reached.contains(q) && pct >= q / 100.0) {
                reached.add(q)
                onQuartileReached?.invoke(q, baseMeta())
            }
        }
        if (!completed && pct >= 0.99) {
            completed = true
            onVideoComplete?.invoke(baseMeta())
        }

        // Viewable: 50% visible + playing for 2s
        val now = System.currentTimeMillis()
        val rect = Rect()
        val isGlobal = containerView.getGlobalVisibleRect(rect)
        val totalArea = containerView.width.toLong() * containerView.height.toLong()
        val visibleArea = rect.width().toLong() * rect.height().toLong()
        val ratio = if (totalArea > 0) visibleArea.toFloat() / totalArea.toFloat() else 0f
        if (playing && !completed && isGlobal && ratio >= 0.5f) {
            if (videoRunStart == 0L) videoRunStart = now
            videoViewAccum += now - videoRunStart
            videoRunStart = now
            if (!videoViewableFired && videoViewAccum >= 2000) {
                videoViewableFired = true
                val meta = baseMeta().toMutableMap()
                val m = (meta["metadata"] as Map<*, *>).toMutableMap()
                m["is_video"] = true
                m["visible_percent"] = (ratio * 100).toDouble()
                m["exposure_time_ms"] = videoViewAccum
                m["viewability_status"] = "video_viewable"
                meta["metadata"] = m
                @Suppress("UNCHECKED_CAST")
                onVideoViewable?.invoke(meta as Map<String, Any?>)
            }
        } else {
            videoRunStart = 0L
        }
        wasPlaying = playing
        wasMuted = muted
        lastPositionMs = pos
    }
}

