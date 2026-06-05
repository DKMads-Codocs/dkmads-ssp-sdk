// DKMads SSP Android SDK
// Kotlin implementation for Android applications

package com.dkmads.ssp

import android.content.Context
import android.os.Build
import android.util.DisplayMetrics
import android.view.View
import android.view.WindowManager
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

private object PublicApiPaths {
    private const val PUBLIC_REST_V1 = "/api/public/v1"

    fun normalizeBase(baseUrl: String): String {
        var normalized = baseUrl.trim().trimEnd('/')
        if (normalized.endsWith("/api/public")) return normalized
        if (normalized.endsWith("/api")) return "$normalized/public"
        if (normalized.endsWith("/v1")) normalized = normalized.removeSuffix("/v1").trimEnd('/')
        return normalized
    }

    fun bidURL(baseUrl: String): String {
        val base = normalizeBase(baseUrl)
        if (base.endsWith("/api/public/v1")) return "$base/bid"
        if (base.endsWith("/api/public")) return "$base/v1/bid"
        return "$base$PUBLIC_REST_V1/bid"
    }
}

/**
 * Main SDK entry point
 */
object SSPSDK {

    private var config: Config? = null
    private var applicationContext: Context? = null
    private val adUnits = mutableMapOf<String, AdUnit>()
    private val telemetryManager = TelemetryManager()
    private var userData: Map<String, Any> = emptyMap()
    private var targetingSignals: TargetingSignals = TargetingSignals()
    private var consentData: ConsentState = ConsentState()
    private var consentConfigured = false

    @Volatile
    var lastBidDiagnostics: DKMadsBidDiagnostics? = null
        private set

    /**
     * Initialize the SDK with configuration
     */
    fun initialize(context: Context, config: Config) {
        this.config = config
        val appContext = context.applicationContext
        applicationContext = appContext
        val defaultDevicePid = DeviceIdentity.getOrCreateDevicePid(appContext)
        if (targetingSignals.devicePid.isNullOrBlank()) {
            targetingSignals = targetingSignals.copy(devicePid = defaultDevicePid)
        }

        telemetryManager.setApplicationContext(appContext)
        telemetryManager.configure(config)
        refreshCmpConsent(appContext)
        telemetryManager.setIdentityProvider {
            val platformUid = userData["platform_uid"]?.toString()
                ?: PlatformIdentity.get(appContext)
            mapOf<String, String?>(
                "user_pid" to (userData["user_pid"]?.toString() ?: targetingSignals.userPid),
                "device_pid" to (
                    userData["device_pid"]?.toString()
                        ?: targetingSignals.devicePid
                        ?: defaultDevicePid
                    ),
                "platform_uid" to platformUid,
                "gaid" to resolveGaid(appContext),
            )
        }
        telemetryManager.trackEvent(
            type = "sdk_init",
            data = mapOf<String, Any?>(
                "platform" to "android",
                "sdkVersion" to SDK_VERSION,
                "deviceType" to getDeviceType(context),
            ),
        )

        if (config.debug) {
            android.util.Log.d("DKMads SSP", "SDK initialized with key: ${config.integrationKey}")
        }
    }

    /**
     * Load an ad for the specified ad unit
     */
    fun canRequestAds(): Boolean {
        val cfg = config ?: return false
        if (cfg.requireConsentBeforeAds) return consentConfigured
        return true
    }

    suspend fun loadAd(
        context: Context,
        adUnitCode: String,
        format: AdFormat,
        sizes: List<Pair<Int, Int>> = emptyList(),
        placementCode: String? = null,
        placementContext: String? = null,
        keyValues: Map<String, Any> = emptyMap()
    ): Result<Ad> = withContext(Dispatchers.IO) {
        val cfg = config ?: return@withContext Result.failure(SDKError.NotInitialized)
        if (!canRequestAds()) {
            return@withContext Result.failure(SDKError.ConsentRequired)
        }

        telemetryManager.trackEvent(
            type = "ad_request",
            data = mapOf<String, Any?>(
                "adUnitCode" to adUnitCode,
                "format" to format.name.lowercase(),
                "placement_code" to placementCode,
                "placement_context" to placementContext,
            ),
        )

        try {
            refreshCmpConsent(context.applicationContext)
            val request = buildAdRequest(
                context,
                adUnitCode,
                format,
                sizes,
                placementCode,
                placementContext,
                mergedKeyValues(keyValues),
            )
            val started = System.currentTimeMillis()
            val response = sendRequest(context, PublicApiPaths.bidURL(cfg.baseUrl), request)
            val latencyMs = (System.currentTimeMillis() - started).toInt()

            val reason = response.optString("reason").takeIf { it.isNotBlank() }
            val requestId = response.optString("request_id").takeIf { it.isNotBlank() }
            val refreshSec = response.optInt("refresh_interval_sec", -1).takeIf { it >= 0 }
            val adData = response.optJSONObject("winner")
            if (adData != null && adData.length() > 0) {
                val adm = adData.optString("adm", "")
                val deliveryType = adData.optString("delivery_type", adData.optString("creative_type", ""))
                val html5EntryUrl = adData.optString("html5_entry_url", "")
                val videoUrl = adData.optString("video_url", "")
                val audioUrl = adData.optString("audio_url", "")
                val imageUrl = adData.optString("image_url", "")
                val creativeUrl = resolveRasterCreativeUrl(adData, imageUrl)
                var resolvedId = adData.optString("id", adData.optString("crid", ""))
                if (resolvedId.isBlank() && creativeUrl.isNotBlank()) {
                    resolvedId = creativeUrl
                } else if (resolvedId.isBlank() && adm.isNotBlank()) {
                    resolvedId = "html-creative"
                }
                val ad = Ad(
                    id = resolvedId,
                    creativeUrl = creativeUrl,
                    clickUrl = adData.optString("clickUrl", adData.optString("click_url", "")),
                    width = adData.optInt("w", adData.optInt("width", 0)),
                    height = adData.optInt("h", adData.optInt("height", 0)),
                    adm = adm,
                    html5EntryUrl = html5EntryUrl,
                    videoUrl = videoUrl,
                    audioUrl = audioUrl,
                    deliveryType = deliveryType.takeIf { it.isNotBlank() },
                    reason = reason ?: "won",
                    requestId = requestId,
                    dsp = adData.optString("dsp").takeIf { it.isNotBlank() },
                    price = adData.optDouble("price").takeIf { !it.isNaN() },
                    campaignId = adData.optString("cid").takeIf { it.isNotBlank() },
                    creativeId = adData.optString("crid").takeIf { it.isNotBlank() },
                    videoTemplate = adData.optString("video_template").takeIf { it.isNotBlank() },
                    ctaLabel = adData.optString("cta_label", "Learn more").ifBlank { "Learn more" },
                    ctaPosition = adData.optString("cta_position").takeIf { it.isNotBlank() },
                    companionImageUrl = adData.optString("companion_image_url").takeIf { it.isNotBlank() },
                    showCompanionClick = adData.takeIf { it.has("show_companion_click") }?.optBoolean("show_companion_click"),
                    skippable = adData.takeIf { it.has("skippable") }?.optBoolean("skippable"),
                    skipAfterSec = adData.takeIf { it.has("skip_after_sec") }?.optDouble("skip_after_sec")?.takeIf { !it.isNaN() },
                    unitFormat = adData.optString("unit_format").takeIf { it.isNotBlank() },
                    placementContext = adData.optString("placement_context").takeIf { it.isNotBlank() },
                    refreshIntervalSec = refreshSec,
                )

                recordBidDiagnostics(adUnitCode, format.name.lowercase(), ad, latencyMs, refreshSec)
                Result.success(ad)
            } else {
                val empty = Ad.empty(reason = reason, requestId = requestId, refreshIntervalSec = refreshSec)
                recordBidDiagnostics(adUnitCode, format.name.lowercase(), empty, latencyMs, refreshSec)
                Result.success(empty)
            }
        } catch (e: Exception) {
            telemetryManager.trackEvent(
                type = "ad_error",
                data = mapOf<String, Any?>("error" to (e.message ?: "Unknown error")),
            )
            recordBidDiagnostics(
                adUnitCode,
                format.name.lowercase(),
                null,
                null,
                null,
                errorMessage = e.message,
            )
            Result.failure(e)
        }
    }

    private fun recordBidDiagnostics(
        adUnitId: String,
        format: String,
        ad: Ad?,
        latencyMs: Int?,
        refreshSec: Int?,
        errorMessage: String? = null,
    ) {
        lastBidDiagnostics = DKMadsBidDiagnostics(
            adUnitId = adUnitId,
            format = format,
            reason = ad?.reason,
            requestId = ad?.requestId,
            dsp = ad?.dsp,
            price = ad?.price,
            latencyMs = latencyMs,
            refreshIntervalSec = refreshSec ?: ad?.refreshIntervalSec,
            loaded = ad?.hasFill == true,
            errorMessage = errorMessage,
        )
    }

    /**
     * Register an ad unit for pre-loading
     */
    fun registerAdUnit(adUnitCode: String, format: AdFormat, sizes: List<Pair<Int, Int>> = emptyList()) {
        adUnits[adUnitCode] = AdUnit(adUnitCode, format, sizes)
        if (config?.debug == true) {
            android.util.Log.d("DKMads SSP", "Registered ad unit: $adUnitCode ($format, sizes=$sizes)")
        }
    }

    /** Sizes from [registerAdUnit] used when load calls omit explicit sizes (e.g. interstitial IAB tokens). */
    fun registeredSizes(adUnitCode: String): List<Pair<Int, Int>> =
        adUnits[adUnitCode]?.sizes.orEmpty()

    /**
     * Set user data for targeting
     */
    fun setUserData(data: Map<String, Any>) {
        userData = data
        if (config?.debug == true) {
            android.util.Log.d("DKMads SSP", "User data updated")
        }
    }

    /**
     * Structured targeting (demographics, geo, interests, segments).
     * Merged into bid `signals` and available for [syncFirstPartyProfile].
     */
    fun setTargetingSignals(signals: TargetingSignals) {
        targetingSignals = signals
        userData = userData + signals.toUserDataMap()
        if (config?.debug == true) {
            android.util.Log.d("DKMads SSP", "Targeting signals updated")
        }
    }

    /** POST /api/public/v1/fpd/mobile — builds profile for audience rules (requires device_pid). */
    suspend fun syncFirstPartyProfile(context: Context, appBundle: String? = null): Result<Unit> =
        withContext(Dispatchers.IO) {
            val cfg = config ?: return@withContext Result.failure(SDKError.NotInitialized)
            val devicePid = targetingSignals.devicePid ?: userData["device_pid"]?.toString()
            if (devicePid.isNullOrBlank()) {
                return@withContext Result.failure(IllegalArgumentException("device_pid is required"))
            }
            try {
                val payload = targetingSignals.toFirstPartyPayload(os = "android", appBundle = appBundle)
                    .toMutableMap()
                payload["device_pid"] = devicePid
                targetingSignals.userPid?.let { payload["user_pid"] = it }
                    ?: userData["user_pid"]?.let { payload["user_pid"] = it }
                val url = URL("${PublicApiPaths.normalizeBase(cfg.baseUrl)}/api/public/v1/fpd/mobile")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("X-Integration-Key", cfg.integrationKey)
                conn.doOutput = true
                val body = JSONObject()
                payload.forEach { (k, v) ->
                    when (v) {
                        is Map<*, *> -> body.put(k, JSONObject(v as Map<*, *>))
                        else -> body.put(k, v)
                    }
                }
                OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
                val code = conn.responseCode
                conn.disconnect()
                if (code in 200..299) Result.success(Unit)
                else Result.failure(Exception("FPD sync failed HTTP $code"))
            } catch (e: Exception) {
                Result.failure(e)
        }
    }

    /**
     * Set consent flags
     */
    fun setConsent(
        gdpr: Boolean = false,
        ccpa: Boolean = false,
        consentString: String? = null,
        gppString: String? = null,
        gppSid: String? = null,
        usPrivacyString: String? = null,
    ) {
        consentData = ConsentState(
            gdpr,
            ccpa,
            consentString,
            gppString,
            gppSid,
            usPrivacyString ?: consentData.usPrivacyString,
        )
        applicationContext?.let { refreshCmpConsent(it) }
        consentConfigured = true
        telemetryManager.setConsent(consentData)
        if (config?.debug == true) {
            android.util.Log.d("DKMads SSP", "Consent updated: GDPR=$gdpr, CCPA=$ccpa")
        }
    }

    fun clearIdentifiers() {
        userData = userData.filterKeys { it != "user_pid" && it != "device_pid" }
    }

    fun trackUserEvent(name: String, attributes: Map<String, Any> = emptyMap()) {
        telemetryManager.trackEvent(
            type = "first_party_signal",
            data = mapOf<String, Any?>(
                "event_name" to name,
                "source" to "app",
                "os" to "android",
                "attributes" to attributes,
                "device_pid" to userData["device_pid"],
                "user_pid" to userData["user_pid"],
            ),
        )
    }

    /**
     Attaches lifecycle + telemetry tracking for a video player instance.
     Event names emitted to `eventListener`:
     video_start, video_25, video_50, video_75, video_100, video_viewable,
     video_pause, video_resume, video_skip, video_mute, video_unmute, video_error.
     */
    fun trackVideoLifecycle(
        adUnitId: String,
        campaignId: String? = null,
        creativeId: String? = null,
        containerView: View,
        durationMsProvider: () -> Long,
        currentPositionMsProvider: () -> Long,
        isPlayingProvider: () -> Boolean,
        isMutedProvider: () -> Boolean = { false },
        skippable: Boolean? = null,
        eventListener: ((String, Map<String, Any?>) -> Unit)? = null
    ): VideoTracker {
        return telemetryManager.trackVideoAd(
            adUnitId = adUnitId,
            campaignId = campaignId,
            creativeId = creativeId,
            containerView = containerView,
            durationMsProvider = durationMsProvider,
            currentPositionMsProvider = currentPositionMsProvider,
            isPlayingProvider = isPlayingProvider,
            isMutedProvider = isMutedProvider,
            skippable = skippable,
            eventListener = eventListener
        )
    }

    fun stopVideoLifecycleTracking(adUnitId: String) {
        telemetryManager.stopVideoTracking(adUnitId)
    }

    /**
     * Audio quartile telemetry: audio_start, audio_25/50/75/100, audio_pause.
     */
    fun trackAudioLifecycle(
        adUnitId: String,
        campaignId: String? = null,
        creativeId: String? = null,
        durationMsProvider: () -> Int,
        positionMsProvider: () -> Int,
        isPlayingProvider: () -> Boolean = { true },
    ): AudioTracker {
        return telemetryManager.trackAudioAd(
            adUnitId = adUnitId,
            campaignId = campaignId,
            creativeId = creativeId,
            durationMsProvider = durationMsProvider,
            positionMsProvider = positionMsProvider,
            isPlayingProvider = isPlayingProvider,
        )
    }

    fun stopAudioLifecycleTracking(adUnitId: String) {
        telemetryManager.stopAudioTracking(adUnitId)
    }

    /** IAB viewability (default: 50% visible for >=1s). */
    fun attachBannerViewability(
        adUnitId: String,
        container: View,
        campaignId: String? = null,
        creativeId: String? = null,
        threshold: Float = 0.5f,
        minExposureTimeMs: Long = 1000,
        onViewable: (() -> Unit)? = null,
    ) {
        val extra = mutableMapOf<String, Any?>("ad_unit_id" to adUnitId)
        campaignId?.takeIf { it.isNotBlank() }?.let { extra["campaign_id"] = it }
        if (!creativeId.isNullOrBlank()) extra["creative_id"] = creativeId
        telemetryManager.trackViewability(
            adUnitId = adUnitId,
            container = container,
            threshold = threshold,
            minExposureTimeMs = minExposureTimeMs,
            extra = extra,
            onViewable = onViewable,
        )
    }

    fun detachBannerViewability(adUnitId: String) {
        telemetryManager.stopViewabilityTracking(adUnitId)
    }

    /** Served impression (maps to `impression_served` on the server). */
    fun recordAdImpression(
        adUnitId: String,
        adId: String,
        campaignId: String? = null,
        creativeId: String? = null,
        dspSource: String? = null,
        reason: String? = null,
    ) {
        val extra = mutableMapOf<String, Any?>(
            "ad_unit_id" to adUnitId,
            "adId" to adId,
        )
        campaignId?.takeIf { it.isNotBlank() }?.let { extra["campaign_id"] = it }
        creativeId?.takeIf { it.isNotBlank() }?.let { extra["creative_id"] = it }
        dspSource?.takeIf { it.isNotBlank() }?.let { extra["dsp_source"] = it }
        reason?.takeIf { it.isNotBlank() }?.let { extra["reason"] = it }
        telemetryManager.trackEvent(type = "ad_impression", data = extra)
    }

    fun recordAdClick(
        adUnitId: String,
        adId: String,
        campaignId: String? = null,
        creativeId: String? = null,
        dspSource: String? = null,
    ) {
        val extra = mutableMapOf<String, Any?>(
            "ad_unit_id" to adUnitId,
            "adId" to adId,
        )
        campaignId?.takeIf { it.isNotBlank() }?.let { extra["campaign_id"] = it }
        creativeId?.takeIf { it.isNotBlank() }?.let { extra["creative_id"] = it }
        dspSource?.takeIf { it.isNotBlank() }?.let { extra["dsp_source"] = it }
        telemetryManager.trackEvent(type = "ad_click", data = extra)
    }

    // Private helper functions

    private fun refreshCmpConsent(context: Context) {
        consentData = CmpConsent.mergeInto(consentData, CmpConsent.readSnapshot(context))
        telemetryManager.setConsent(consentData)
    }

    private fun mergedKeyValues(keyValues: Map<String, Any>): Map<String, Any> {
        if (config?.useTestAds != true) return keyValues
        if (keyValues.containsKey("test_mode")) return keyValues
        return keyValues + ("test_mode" to true)
    }

    private fun buildAdRequest(
        context: Context,
        adUnitCode: String,
        format: AdFormat,
        sizes: List<Pair<Int, Int>>,
        placementCode: String?,
        placementContext: String?,
        keyValues: Map<String, Any>
    ): JSONObject {
        val deviceInfo = getDeviceInfo(context)

        return JSONObject().apply {
            put("ad_unit_id", adUnitCode)
            placementCode?.trim()?.takeIf { it.isNotEmpty() }?.let { put("placement_code", it) }
            placementContext?.trim()?.takeIf { it.isNotEmpty() }?.let { put("placement_context", it) }
            put("key_values", JSONObject(keyValues))
            put("request", JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("format", format.name.lowercase())
                put("device_type", getDeviceType(context))
                put("os", "android")
                put("sizes", JSONArray(sizes.map { "${it.first}x${it.second}" }))
                sizes.firstOrNull()?.let {
                    put("w", it.first)
                    put("h", it.second)
                }
                put("device", deviceInfo)
                targetingSignals.geoCountry?.let { put("geo_country", it) }
                targetingSignals.connectionType?.let { put("connection_type", it) }
                targetingSignals.contentCategory?.let { put("content_category", it) }
                targetingSignals.pageType?.let { put("page_type", it) }
            })
            put("signals", JSONObject().apply {
                val signalMap = targetingSignals.toSignalsMap() + userData
                put("user_pid", signalMap["user_pid"])
                put("device_pid", signalMap["device_pid"])
                PlatformIdentity.get(context)?.let { put("platform_uid", it) }
                resolveGaid(context)?.let { put("gaid", it) }
                put("tcf_string", consentData.consentString ?: "")
                put("gpp_string", consentData.gppString ?: "")
                put("gpp_sid", consentData.gppSid ?: "")
                put("gdpr", consentData.gdpr)
                consentData.resolvedUsPrivacyString()?.let { usp ->
                    put("us_privacy", usp)
                    put("us_privacy_string", usp)
                }
                for ((k, v) in signalMap) {
                    if (k in listOf("user_pid", "device_pid")) continue
                    when (v) {
                        is Map<*, *> -> put(k, JSONObject(v as Map<*, *>))
                        is List<*> -> put(k, JSONArray(v))
                        is Number -> put(k, v)
                        is String -> put(k, v)
                        is Boolean -> put(k, v)
                        null -> Unit
                        else -> put(k, v.toString())
                    }
                }
                targetingSignals.contentCategory?.let { put("content_category", it) }
                targetingSignals.pageType?.let { put("page_type", it) }
            })
            put("response_format", "json")
            put("debug", config?.effectiveDebug == true)
        }
    }

    private fun resolveGaid(context: Context): String? {
        if (!consentData.allowsAdvertisingId()) return null
        userData["gaid"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
        return AdvertisingIds.getGaid(context)
    }

    private fun getDeviceType(context: Context): String {
        val metrics = DisplayMetrics()
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager.defaultDisplay.getMetrics(metrics)

        val widthDp = metrics.widthPixels / metrics.density
        return when {
            widthDp < 600 -> "mobile"
            widthDp < 840 -> "tablet"
            else -> "desktop"
        }
    }

    private fun getDeviceInfo(context: Context): JSONObject {
        val metrics = DisplayMetrics()
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager.defaultDisplay.getMetrics(metrics)

        return JSONObject().apply {
            put("type", getDeviceType(context))
            put("os", "Android")
            put("osVersion", Build.VERSION.SDK_INT)
            put("model", Build.MODEL)
            put("screenWidth", metrics.widthPixels)
            put("screenHeight", metrics.heightPixels)
        }
    }

    private fun sendRequest(context: Context, urlString: String, body: JSONObject): JSONObject {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection

        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-Integration-Key", config?.integrationKey ?: "")
            connection.doOutput = true

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body.toString())
            }

            val responseCode = connection.responseCode
            PlatformIdentity.saveFromHeader(context, connection.getHeaderField("X-DKMads-Platform-Uid"))
            if (responseCode == 200) {
                val reader = connection.inputStream.bufferedReader()
                val response = reader.readText()
                return JSONObject(response)
            } else {
                throw SDKError.NetworkError
            }
        } finally {
            connection.disconnect()
        }
    }
}

// Configuration data class
data class Config(
    val integrationKey: String,
    val propertyId: String? = null,
    val propertyCode: String? = null,
    val debug: Boolean = false,
    val baseUrl: String = "https://ssp.dkmads.com",
    val requireConsentBeforeAds: Boolean = false,
    val useTestAds: Boolean = false,
) {
    val effectiveDebug: Boolean get() = debug || useTestAds
}

data class ConsentState(
    val gdpr: Boolean = false,
    val ccpa: Boolean = false,
    val consentString: String? = null,
    val gppString: String? = null,
    val gppSid: String? = null,
    val usPrivacyString: String? = null,
) {
    fun resolvedUsPrivacyString(): String? {
        val trimmed = usPrivacyString?.trim()
        return trimmed?.takeIf { it.isNotEmpty() }
    }

    /** Gate GAID on bid/events — aligns with server assessBidConsent (client-side subset). */
    fun allowsAdvertisingId(): Boolean {
        if (gdpr) {
            val cs = consentString?.trim()
            if (cs.isNullOrEmpty()) return false
        }
        resolvedUsPrivacyString()?.let { usp ->
            if (usp.length >= 3 && usp[2] == 'Y') return false
        }
        return true
    }
}

// Ad format enum
enum class AdFormat {
    BANNER,
    INTERSTITIAL,
    NATIVE,
    REWARDED,
    VIDEO,
    AUDIO,
    SPLASH,
}

// Ad unit data class
data class AdUnit(
    val code: String,
    val format: AdFormat,
    val sizes: List<Pair<Int, Int>>
)

private fun isHtml5AssetUrl(url: String): Boolean {
    val u = url.trim().lowercase()
    if (u.isEmpty()) return false
    return u.contains("/html5/") || u.endsWith(".html") || u.endsWith(".htm")
}

private fun isRasterImageUrl(url: String): Boolean {
    val u = url.trim().lowercase()
    if (u.isEmpty() || isHtml5AssetUrl(u)) return false
    return Regex("""\.(jpe?g|png|gif|webp|avif|bmp|svg)(\?|#|$)""").containsMatchIn(u)
}

private fun resolveRasterCreativeUrl(adData: JSONObject, imageUrl: String): String {
    val delivery = adData.optString("delivery_type", adData.optString("creative_type", ""))
    if (delivery.equals("html5", ignoreCase = true)) return ""
    if (isRasterImageUrl(imageUrl)) return imageUrl
    val direct = adData.optString("creativeUrl", "")
    return if (isRasterImageUrl(direct)) direct else ""
}

// Ad data class
data class Ad(
    val id: String,
    val creativeUrl: String,
    val clickUrl: String,
    val width: Int,
    val height: Int,
    val adm: String = "",
    val html5EntryUrl: String = "",
    val videoUrl: String = "",
    val audioUrl: String = "",
    val deliveryType: String? = null,
    val reason: String? = null,
    val requestId: String? = null,
    val dsp: String? = null,
    val price: Double? = null,
    val campaignId: String? = null,
    val creativeId: String? = null,
    /** House/web parity: video_instream | video_outstream | display_video | rewarded | splash */
    val videoTemplate: String? = null,
    val ctaLabel: String = "Learn more",
    val ctaPosition: String? = null,
    val companionImageUrl: String? = null,
    val showCompanionClick: Boolean? = null,
    val skippable: Boolean? = null,
    val skipAfterSec: Double? = null,
    val unitFormat: String? = null,
    val placementContext: String? = null,
    val refreshIntervalSec: Int? = null,
    /** Set after [recordAdImpression] (avoids duplicate on [DKMadsVideoAdView.display] / interstitial). */
    val impressionRecorded: Boolean = false,
) {
    val isHtml5: Boolean
        get() = deliveryType.equals("html5", ignoreCase = true)
            || html5EntryUrl.isNotBlank()
            || (adm.contains("<iframe", ignoreCase = true) || adm.contains("/html5/"))

    val isVideo: Boolean
        get() {
            if (isHtml5 || isAudio) return false
            val dt = deliveryType?.lowercase().orEmpty()
            if (dt == "video" || dt == "rewarded" || dt == "splash") return true
            if (videoUrl.isNotBlank()) return true
            if (adm.contains("<video", ignoreCase = true)) return true
            return false
        }

    val isAudio: Boolean
        get() {
            if (deliveryType.equals("audio", ignoreCase = true)) return true
            if (audioUrl.isNotBlank()) return true
            if (adm.contains("<audio", ignoreCase = true)) return true
            return false
        }

    /** Fill when renderable markup exists (house winners may omit id/crid). */
    val hasFill: Boolean
        get() = isVideo
            || (isAudio && (audioUrl.isNotBlank() || adm.isNotBlank()))
            || (isHtml5 && (adm.isNotBlank() || html5EntryUrl.isNotBlank()))
            || adm.isNotBlank()
            || creativeUrl.isNotBlank()

    companion object {
        fun empty(reason: String? = null, requestId: String? = null, refreshIntervalSec: Int? = null) =
            Ad("", "", "", 0, 0, reason = reason, requestId = requestId, refreshIntervalSec = refreshIntervalSec)
    }
}

// SDK errors
sealed class SDKError : Exception() {
    object NotInitialized : SDKError()
    object NetworkError : SDKError()
    object NoFill : SDKError()
    object ConsentRequired : SDKError()
    object AdExpired : SDKError()
}

// SDK version
const val SDK_VERSION = "0.5.12"
