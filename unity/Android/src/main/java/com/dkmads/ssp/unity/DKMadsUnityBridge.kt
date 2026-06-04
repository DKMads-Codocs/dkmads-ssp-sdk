package com.dkmads.ssp.unity

import android.app.Activity
import com.dkmads.ssp.Ad
import com.dkmads.ssp.AdFormat
import com.dkmads.ssp.Config
import com.dkmads.ssp.DKMadsAdInspector
import com.dkmads.ssp.DKMadsAppOpenAd
import com.dkmads.ssp.DKMadsInterstitialActivity
import com.dkmads.ssp.DKMadsInterstitialAd
import com.dkmads.ssp.DKMadsResponseInfo
import com.dkmads.ssp.DKMadsRewardedAd
import com.dkmads.ssp.SSPSDK
import com.dkmads.ssp.TargetingSignals
import com.dkmads.ssp.TelemetryManager
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

object DKMadsUnityBridge {
  private val pendingInterstitialAds = mutableMapOf<String, Ad>()
  private val pendingAppOpenAds = mutableMapOf<String, DKMadsAppOpenAd>()
  private val pendingRewardedAds = mutableMapOf<String, DKMadsRewardedAd>()

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
      "splash" -> AdFormat.SPLASH
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
  fun setConsent(jsonPayload: String) {
    val raw = parseJson(jsonPayload)
    val attRaw = raw["attStatus"] ?: raw["att_status"]
    val attStatus = when (attRaw) {
      is Number -> attRaw.toInt()
      is String -> attRaw.toIntOrNull()
      else -> null
    }
    SSPSDK.setConsent(
      gdpr = raw["gdpr"] as? Boolean ?: false,
      ccpa = raw["ccpa"] as? Boolean ?: false,
      consentString = raw["consentString"]?.toString() ?: raw["consent_string"]?.toString(),
      gppString = raw["gppString"]?.toString() ?: raw["gpp_string"]?.toString(),
      gppSid = raw["gppSid"]?.toString() ?: raw["gpp_sid"]?.toString(),
      usPrivacyString = raw["usPrivacyString"]?.toString() ?: raw["us_privacy_string"]?.toString(),
    )
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
        dateOfBirth = raw["date_of_birth"]?.toString() ?: raw["dateOfBirth"]?.toString() ?: raw["dob"]?.toString(),
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
  fun loadAppOpen(activity: Activity, adUnitId: String): String = runBlocking {
    val deferred = CompletableDeferred<JSONObject>()
    val appOpen = DKMadsAppOpenAd(adUnitId).apply {
      listener = object : DKMadsAppOpenAd.Listener {
        override fun onAdLoaded(appOpen: DKMadsAppOpenAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
          pendingAppOpenAds[adUnitId] = appOpen
          val payload = JSONObject()
          payload.putFromAd(ad)
          deferred.complete(payload)
        }
        override fun onAdFailed(appOpen: DKMadsAppOpenAd, message: String, responseInfo: DKMadsResponseInfo?) {
          deferred.complete(
            JSONObject().apply {
              put("success", false)
              put("reason", message)
            },
          )
        }
      }
    }
    appOpen.load(activity.applicationContext)
    deferred.await().toString()
  }

  @JvmStatic
  fun showAppOpen(activity: Activity, adUnitId: String) {
    pendingAppOpenAds[adUnitId]?.show(activity)
  }

  @JvmStatic
  fun presentAdInspector(activity: Activity) {
    DKMadsAdInspector.present(activity)
  }

  @JvmStatic
  fun loadRewarded(activity: Activity, adUnitId: String, width: Int, height: Int): String =
    runBlocking {
      val rewarded = DKMadsRewardedAd(adUnitId).apply {
        adWidth = width
        adHeight = height
      }
      val payload = JSONObject()
      rewarded.listener = object : DKMadsRewardedAd.Listener {
        override fun onAdLoaded(rewarded: DKMadsRewardedAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
          pendingRewardedAds[adUnitId] = rewarded
          payload.putFromAd(ad)
        }

        override fun onAdFailed(rewarded: DKMadsRewardedAd, message: String, responseInfo: DKMadsResponseInfo?) {
          payload.put("success", false)
          payload.put("reason", message)
        }
      }
      rewarded.load(activity.applicationContext)
      payload.toString()
    }

  @JvmStatic
  fun showRewarded(activity: Activity, adUnitId: String): String {
    val rewarded = pendingRewardedAds[adUnitId]
    if (rewarded == null || rewarded.loadedAd == null) return "{\"success\":false,\"reason\":\"not_loaded\"}"
    rewarded.listener = object : DKMadsRewardedAd.Listener {
      override fun onUserEarnedReward(rewarded: DKMadsRewardedAd) {
        TelemetryManager.shared.trackEvent("rewarded_earned", mapOf("ad_unit_id" to adUnitId))
      }
    }
    rewarded.show(activity)
    return "{\"success\":true}"
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
        "splash" -> AdFormat.SPLASH
        else -> AdFormat.BANNER
      }
      val sizes = if (formatEnum == AdFormat.INTERSTITIAL || formatEnum == AdFormat.SPLASH) {
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
  fun syncFirstPartyProfile(activity: Activity, appBundle: String?) {
    kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.Main) {
      SSPSDK.syncFirstPartyProfile(activity.applicationContext, appBundle)
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
    put("videoTemplate", ad.videoTemplate ?: JSONObject.NULL)
    put("ctaLabel", ad.ctaLabel)
    put("ctaPosition", ad.ctaPosition ?: JSONObject.NULL)
    put("companionImageUrl", ad.companionImageUrl ?: JSONObject.NULL)
    put("showCompanionClick", ad.showCompanionClick ?: JSONObject.NULL)
    put("skippable", ad.skippable ?: JSONObject.NULL)
    put("skipAfterSec", ad.skipAfterSec ?: JSONObject.NULL)
    put("unitFormat", ad.unitFormat ?: JSONObject.NULL)
    put("placementContext", ad.placementContext ?: JSONObject.NULL)
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
