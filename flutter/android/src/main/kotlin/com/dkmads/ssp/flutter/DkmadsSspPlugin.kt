package com.dkmads.ssp.flutter

import android.content.Context
import com.dkmads.ssp.Ad
import com.dkmads.ssp.AdFormat
import com.dkmads.ssp.Config
import com.dkmads.ssp.DKMadsInterstitialAd
import com.dkmads.ssp.SSPSDK
import com.dkmads.ssp.TargetingSignals
import com.dkmads.ssp.TelemetryManager
import kotlinx.coroutines.runBlocking
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

private fun adToMap(ad: Ad): Map<String, Any?> = mapOf(
  "success" to ad.hasFill,
  "reason" to ad.reason,
  "requestId" to ad.requestId,
  "adId" to ad.id,
  "adm" to ad.adm,
  "creativeUrl" to ad.creativeUrl,
  "clickUrl" to ad.clickUrl,
  "videoUrl" to ad.videoUrl,
  "audioUrl" to ad.audioUrl,
  "html5EntryUrl" to ad.html5EntryUrl,
  "isAudio" to ad.isAudio,
  "width" to ad.width,
  "height" to ad.height,
  "isVideo" to ad.isVideo,
  "isHtml5" to ad.isHtml5,
  "dsp" to ad.dsp,
  "price" to ad.price,
  "campaignId" to ad.campaignId,
  "creativeId" to ad.creativeId,
)

class DkmadsSspPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context
  private val activeVideoUnits = linkedSetOf<String>()
  private val interstitials = mutableMapOf<String, DKMadsInterstitialAd>()
  private fun sendVideoEvent(adUnitId: String, eventName: String, payload: Map<String, Any?>) {
    val args = mapOf(
      "adUnitId" to adUnitId,
      "eventName" to eventName,
      "payload" to payload,
    )
    channel.invokeMethod("videoEvent", args)
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "dkmads_ssp")
    channel.setMethodCallHandler(this)
  }

  @Suppress("UNCHECKED_CAST")
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> {
        val integrationKey = call.argument<String>("integrationKey")
        if (integrationKey.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "integrationKey is required", null)
          return
        }
        val cfg = Config(
          integrationKey = integrationKey,
          propertyId = call.argument<String>("propertyId"),
          propertyCode = call.argument<String>("propertyCode"),
          debug = call.argument<Boolean>("debug") ?: false,
          baseUrl = call.argument<String>("baseUrl") ?: "https://ssp.dkmads.com",
        )
        SSPSDK.initialize(appContext, cfg)
        result.success(null)
      }
      "setUserData" -> {
        val userData = (call.argument<Map<String, Any?>>("userData") ?: emptyMap())
          .mapValues { it.value ?: "" }
        SSPSDK.setUserData(userData)
        result.success(null)
      }
      "setTargetingSignals" -> {
        val m = call.argument<Map<String, Any?>>("signals") ?: emptyMap()
        val interests = (m["interests"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
        val keywords = (m["keywords"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
        val segments = (m["segments"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
        SSPSDK.setTargetingSignals(
          TargetingSignals(
            userPid = m["userPid"]?.toString() ?: m["user_pid"]?.toString(),
            devicePid = m["devicePid"]?.toString() ?: m["device_pid"]?.toString(),
            gender = m["gender"]?.toString(),
            age = (m["age"] as? Number)?.toInt(),
            yob = (m["yob"] as? Number)?.toInt(),
            geoCountry = m["geoCountry"]?.toString() ?: m["geo_country"]?.toString(),
            geoRegion = m["geoRegion"]?.toString() ?: m["geo_region"]?.toString(),
            interests = interests,
            keywords = keywords,
            segments = segments,
            connectionType = m["connectionType"]?.toString() ?: m["connection_type"]?.toString(),
            contentCategory = m["contentCategory"]?.toString() ?: m["content_category"]?.toString(),
            pageType = m["pageType"]?.toString() ?: m["page_type"]?.toString(),
          ),
        )
        result.success(null)
      }
      "syncFirstPartyProfile" -> {
        val bundle = call.argument<String>("appBundle")
        runBlocking {
          val r = SSPSDK.syncFirstPartyProfile(appContext, bundle)
          if (r.isSuccess) result.success(null)
          else result.error("FPD_SYNC_FAILED", r.exceptionOrNull()?.message, null)
        }
      }
      "setConsent" -> {
        SSPSDK.setConsent(
          gdpr = call.argument<Boolean>("gdpr") ?: false,
          ccpa = call.argument<Boolean>("ccpa") ?: false,
          consentString = call.argument<String>("consentString"),
          gppString = call.argument<String>("gppString"),
          gppSid = call.argument<String>("gppSid"),
        )
        result.success(null)
      }
      "clearIdentifiers" -> {
        SSPSDK.clearIdentifiers()
        result.success(null)
      }
      "registerAdUnit" -> {
        val adUnitId = call.argument<String>("adUnitId")
        val formatRaw = call.argument<String>("format") ?: "banner"
        if (adUnitId.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId is required", null)
          return
        }
        val format = when (formatRaw.lowercase()) {
          "interstitial" -> AdFormat.INTERSTITIAL
          "native" -> AdFormat.NATIVE
          "video" -> AdFormat.VIDEO
          "rewarded" -> AdFormat.REWARDED
          "audio" -> AdFormat.AUDIO
          else -> AdFormat.BANNER
        }
        @Suppress("UNCHECKED_CAST")
        val sizeMaps = call.argument<List<Map<String, Int>>>("sizes") ?: emptyList()
        val sizes = sizeMaps.mapNotNull { m ->
          val w = m["width"] ?: return@mapNotNull null
          val h = m["height"] ?: return@mapNotNull null
          w to h
        }
        SSPSDK.registerAdUnit(adUnitId, format, sizes)
        result.success(null)
      }
      "loadBanner" -> {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId is required", null)
          return
        }
        val width = call.argument<Int>("width") ?: 300
        val height = call.argument<Int>("height") ?: 250
        val placementCode = call.argument<String>("placementCode")
        val placementContext = call.argument<String>("placementContext")
        Thread {
          try {
            val loadResult = runBlocking {
              SSPSDK.loadAd(
                context = appContext,
                adUnitCode = adUnitId,
                format = AdFormat.BANNER,
                sizes = listOf(width to height),
                placementCode = placementCode,
                placementContext = placementContext,
              )
            }
            val payload = loadResult.fold(
              onSuccess = { ad -> adToMap(ad) },
              onFailure = { err ->
                mapOf(
                  "success" to false,
                  "reason" to "network_error",
                  "error" to (err.message ?: "unknown"),
                )
              },
            )
            result.success(payload)
          } catch (err: Throwable) {
            result.error("LOAD_FAILED", err.message, null)
          }
        }.start()
      }
      "loadInterstitial" -> {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId is required", null)
          return
        }
        val width = call.argument<Int>("width") ?: 320
        val height = call.argument<Int>("height") ?: 480
        val placementCode = call.argument<String>("placementCode")
        val placementContext = call.argument<String>("placementContext")
        val interstitial = DKMadsInterstitialAd(adUnitId).apply {
          this.adWidth = width
          this.adHeight = height
          listener = object : DKMadsInterstitialAd.Listener {
            override fun onAdLoaded(interstitial: DKMadsInterstitialAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
              interstitials[adUnitId] = interstitial
              result.success(adToMap(ad))
            }
            override fun onAdFailed(interstitial: DKMadsInterstitialAd, message: String, responseInfo: DKMadsResponseInfo?) {
              result.success(
                mapOf(
                  "success" to false,
                  "reason" to message,
                ),
              )
            }
          }
        }
        interstitial.load(
          appContext,
          placementCode = placementCode,
          placementContext = placementContext,
        )
      }
      "showInterstitial" -> {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId is required", null)
          return
        }
        val interstitial = interstitials[adUnitId]
        if (interstitial == null || interstitial.loadedAd == null) {
          result.error("NOT_LOADED", "Call loadInterstitial first", null)
          return
        }
        interstitial.show(appContext)
        result.success(null)
      }
      "trackUserEvent" -> {
        val name = call.argument<String>("name")
        if (name.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "name is required", null)
          return
        }
        val attributes = (call.argument<Map<String, Any?>>("attributes") ?: emptyMap())
          .mapValues { it.value ?: "" }
        SSPSDK.trackUserEvent(name, attributes)
        result.success(null)
      }
      "trackVideoLifecycle" -> {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId is required", null)
          return
        }
        activeVideoUnits.add(adUnitId)
        sendVideoEvent(
          adUnitId = adUnitId,
          eventName = "lifecycle_tracking_started",
          payload = mapOf("source" to "flutter_android_plugin"),
        )
        result.success(null)
      }
      "emitVideoEvent" -> {
        val adUnitId = call.argument<String>("adUnitId")
        val eventName = call.argument<String>("eventName")
        if (adUnitId.isNullOrBlank() || eventName.isNullOrBlank()) {
          result.error("INVALID_ARGUMENT", "adUnitId and eventName are required", null)
          return
        }
        if (!activeVideoUnits.contains(adUnitId)) {
          result.error("NOT_TRACKING", "trackVideoLifecycle must be called first for this adUnitId", null)
          return
        }
        val payload = (call.argument<Map<String, Any?>>("payload") ?: emptyMap()).toMutableMap()
        payload["ad_unit_id"] = adUnitId
        TelemetryManager.shared.trackEvent(eventName, payload)
        sendVideoEvent(
          adUnitId = adUnitId,
          eventName = eventName,
          payload = payload,
        )
        result.success(null)
      }
      "stopVideoLifecycleTracking" -> {
        val adUnitId = call.argument<String>("adUnitId")
        if (!adUnitId.isNullOrBlank()) {
          activeVideoUnits.remove(adUnitId)
          SSPSDK.stopVideoLifecycleTracking(adUnitId)
          sendVideoEvent(
            adUnitId = adUnitId,
            eventName = "lifecycle_tracking_stopped",
            payload = mapOf("source" to "flutter_android_plugin"),
          )
        }
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
