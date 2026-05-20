package com.dkmads.ssp.unity

import android.app.Activity
import com.dkmads.ssp.Ad
import com.dkmads.ssp.AdFormat
import com.dkmads.ssp.Config
import com.dkmads.ssp.DKMadsInterstitialActivity
import com.dkmads.ssp.DKMadsInterstitialAd
import com.dkmads.ssp.SSPSDK
import com.dkmads.ssp.TargetingSignals
import com.dkmads.ssp.TelemetryManager
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

object DKMadsUnityBridge {
  private val pendingInterstitialAds = mutableMapOf<String, Ad>()

  @JvmStatic
  fun initialize(activity: Activity, integrationKey: String, propertyId: String?, propertyCode: String?) {
    val config = Config(
      integrationKey = integrationKey,
      propertyId = propertyId,
      propertyCode = propertyCode,
      debug = false,
      baseUrl = "https://ssp.dkmads.com"
    )
    SSPSDK.initialize(activity.applicationContext, config)
  }

  @JvmStatic
  fun registerAdUnit(adUnitId: String, format: String, sizesJson: String) {
    val formatEnum = when (format.lowercase()) {
      "interstitial" -> AdFormat.INTERSTITIAL
      "native" -> AdFormat.NATIVE
      "video" -> AdFormat.VIDEO
      "rewarded" -> AdFormat.REWARDED
      "audio" -> AdFormat.AUDIO
      else -> AdFormat.BANNER
    }
    val sizes = mutableListOf<Pair<Int, Int>>()
    if (sizesJson.isNotBlank()) {
      try {
        val arr = org.json.JSONArray(sizesJson)
        for (i in 0 until arr.length()) {
          val item = arr.optJSONObject(i) ?: continue
          val w = item.optInt("width", 0)
          val h = item.optInt("height", 0)
          if (w > 0 && h > 0) sizes.add(w to h)
        }
      } catch (_: Throwable) { }
    }
    SSPSDK.registerAdUnit(adUnitId, formatEnum, sizes)
  }

  @JvmStatic
  fun setTargetingSignals(jsonPayload: String) {
    val raw = parseJson(jsonPayload)
    val interests = (raw["interests"] as? List<*>)?.mapNotNull { it?.toString() }
      ?: (raw["interests"] as? org.json.JSONArray)?.let { arr ->
        (0 until arr.length()).mapNotNull { i -> arr.optString(i).takeIf { it.isNotBlank() } }
      }
      ?: emptyList()
    val keywords = (raw["keywords"] as? List<*>)?.mapNotNull { it?.toString() }
      ?: (raw["keywords"] as? org.json.JSONArray)?.let { arr ->
        (0 until arr.length()).mapNotNull { i -> arr.optString(i).takeIf { it.isNotBlank() } }
      }
      ?: emptyList()
    val segments = (raw["segments"] as? List<*>)?.mapNotNull { it?.toString() }
      ?: (raw["segments"] as? org.json.JSONArray)?.let { arr ->
        (0 until arr.length()).mapNotNull { i -> arr.optString(i).takeIf { it.isNotBlank() } }
      }
      ?: emptyList()
    SSPSDK.setTargetingSignals(
      TargetingSignals(
        userPid = raw["user_pid"]?.toString() ?: raw["userPid"]?.toString(),
        devicePid = raw["device_pid"]?.toString() ?: raw["devicePid"]?.toString(),
        gender = raw["gender"]?.toString(),
        age = (raw["age"] as? Number)?.toInt() ?: raw["age"]?.toString()?.toIntOrNull(),
        yob = (raw["yob"] as? Number)?.toInt() ?: raw["yob"]?.toString()?.toIntOrNull(),
        geoCountry = raw["geo_country"]?.toString() ?: raw["geoCountry"]?.toString(),
        geoRegion = raw["geo_region"]?.toString() ?: raw["geoRegion"]?.toString(),
        interests = interests,
        keywords = keywords,
        segments = segments,
        connectionType = raw["connection_type"]?.toString() ?: raw["connectionType"]?.toString(),
        contentCategory = raw["content_category"]?.toString() ?: raw["contentCategory"]?.toString(),
        pageType = raw["page_type"]?.toString() ?: raw["pageType"]?.toString(),
      ),
    )
  }

  @JvmStatic
  fun setUserData(jsonPayload: String) {
    val raw = parseJson(jsonPayload)
    val cleaned = raw.filterValues { it != null }.mapValues { (_, v) -> v as Any }
    SSPSDK.setUserData(cleaned)
  }

  @JvmStatic
  fun trackUserEvent(name: String, jsonPayload: String) {
    val attrs = parseJson(jsonPayload)
    SSPSDK.trackUserEvent(name, attrs)
  }

  @JvmStatic
  fun loadAd(activity: Activity, adUnitId: String, width: Int, height: Int): String =
    loadAdWithFormat(activity, adUnitId, "banner", width, height)

  @JvmStatic
  fun loadInterstitial(activity: Activity, adUnitId: String, width: Int, height: Int): String =
    runBlocking {
      val sizes = DKMadsInterstitialAd.bidSizes(adUnitId, width, height)
      val loadResult = SSPSDK.loadAd(
        context = activity.applicationContext,
        adUnitCode = adUnitId,
        format = AdFormat.INTERSTITIAL,
        sizes = sizes,
      )
      val payload = JSONObject()
      loadResult.fold(
        onSuccess = { ad ->
          if (ad.hasFill) pendingInterstitialAds[adUnitId] = ad
          payload.putFromAd(ad)
        },
        onFailure = { err ->
          payload.put("success", false)
          payload.put("reason", "network_error")
          payload.put("error", err.message ?: "unknown")
        },
      )
      payload.toString()
    }

  @JvmStatic
  fun showInterstitial(activity: Activity, adUnitId: String) {
    val ad = pendingInterstitialAds[adUnitId] ?: return
    DKMadsInterstitialActivity.present(
      context = activity,
      adUnitId = adUnitId,
      ad = ad,
      callbacks = DKMadsInterstitialActivity.Callbacks(),
    )
  }

  @JvmStatic
  fun loadAdWithFormat(activity: Activity, adUnitId: String, format: String, width: Int, height: Int): String {
    return runBlocking {
      val formatEnum = when (format.lowercase()) {
        "interstitial" -> AdFormat.INTERSTITIAL
        "native" -> AdFormat.NATIVE
        "video" -> AdFormat.VIDEO
        "rewarded" -> AdFormat.REWARDED
        "audio" -> AdFormat.AUDIO
        else -> AdFormat.BANNER
      }
      val sizes = if (formatEnum == AdFormat.INTERSTITIAL) {
        DKMadsInterstitialAd.bidSizes(adUnitId, width, height)
      } else {
        listOf(width to height)
      }
      val loadResult = SSPSDK.loadAd(
        context = activity.applicationContext,
        adUnitCode = adUnitId,
        format = formatEnum,
        sizes = sizes,
      )
      val payload = JSONObject()
      loadResult.fold(
        onSuccess = { ad -> payload.putFromAd(ad) },
        onFailure = { err ->
          payload.put("success", false)
          payload.put("reason", "network_error")
          payload.put("error", err.message ?: "unknown")
        },
      )
      payload.toString()
    }
  }

  @JvmStatic
  fun emitVideoEvent(adUnitId: String, eventName: String, jsonPayload: String) {
    val attrs = parseJson(jsonPayload).toMutableMap()
    attrs["ad_unit_id"] = adUnitId
    TelemetryManager.shared.trackEvent(eventName, attrs)
  }

  private fun JSONObject.putFromAd(ad: Ad) {
    put("success", ad.hasFill)
    put("reason", ad.reason ?: JSONObject.NULL)
    put("requestId", ad.requestId ?: JSONObject.NULL)
    put("adId", ad.id)
    put("adm", ad.adm)
    put("creativeUrl", ad.creativeUrl)
    put("clickUrl", ad.clickUrl)
    put("videoUrl", ad.videoUrl)
    put("audioUrl", ad.audioUrl)
    put("html5EntryUrl", ad.html5EntryUrl)
    put("isAudio", ad.isAudio)
    put("width", ad.width)
    put("height", ad.height)
    put("isVideo", ad.isVideo)
    put("isHtml5", ad.isHtml5)
    put("dsp", ad.dsp ?: JSONObject.NULL)
    put("price", ad.price ?: JSONObject.NULL)
    put("campaignId", ad.campaignId ?: JSONObject.NULL)
    put("creativeId", ad.creativeId ?: JSONObject.NULL)
  }

  private fun parseJson(raw: String): Map<String, Any?> {
    if (raw.isBlank()) return emptyMap()
    return try {
      val json = JSONObject(raw)
      json.keys().asSequence().associateWith { key -> json.opt(key) }
    } catch (_: Throwable) {
      emptyMap()
    }
  }
}
