import Flutter
import UIKit

public class DkmadsSspPlugin: NSObject, FlutterPlugin {
  private var activeVideoUnits = Set<String>()
  private var interstitials: [String: DKMadsInterstitialAd] = [:]
  private var appOpenAds: [String: DKMadsAppOpenAd] = [:]
  private var rewardedAds: [String: DKMadsRewardedAd] = [:]
  private var channel: FlutterMethodChannel?

  private func adPayload(from ad: Ad, success: Bool, reason: String?, requestId: String?, dsp: String?, price: Double?) -> [String: Any] {
    [
      "success": success,
      "reason": reason as Any,
      "requestId": requestId as Any,
      "adId": ad.id,
      "adm": ad.adm as Any,
      "creativeUrl": ad.creativeUrl,
      "clickUrl": ad.clickUrl,
      "videoUrl": ad.videoUrl as Any,
      "html5EntryUrl": ad.html5EntryUrl as Any,
      "width": ad.width,
      "height": ad.height,
      "isVideo": ad.isVideo,
      "isHtml5": ad.isHTML5,
      "dsp": dsp as Any,
      "price": price as Any,
      "campaignId": ad.campaignId as Any,
      "creativeId": ad.creativeId as Any,
      "videoTemplate": ad.videoTemplate as Any,
      "ctaLabel": ad.ctaLabel,
      "ctaPosition": ad.ctaPosition as Any,
      "companionImageUrl": ad.companionImageUrl as Any,
      "showCompanionClick": ad.showCompanionClick as Any,
      "skippable": ad.skippable as Any,
      "skipAfterSec": ad.skipAfterSec as Any,
      "unitFormat": ad.unitFormat as Any,
      "placementContext": ad.placementContext as Any,
    ]
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
    guard var top = window?.rootViewController else { return nil }
    while let presented = top.presentedViewController { top = presented }
    return top
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dkmads_ssp", binaryMessenger: registrar.messenger())
    let instance = DkmadsSspPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    let factory = DkmadsInstreamViewFactory(messenger: registrar.messenger()) { viewId, event, payload in
      instance.sendInstreamEvent(viewId: viewId, event: event, payload: payload)
    }
    registrar.register(factory, withId: "dkmads_instream")
    registrar.register(
      DkmadsBannerViewFactory(),
      withId: "dkmads_banner"
    )
  }

  private func sendInstreamEvent(viewId: Int64, event: String, payload: [String: Any]) {
    var args: [String: Any] = ["viewId": viewId, "event": event]
    payload.forEach { args[$0.key] = $0.value }
    channel?.invokeMethod("instreamEvent", arguments: args)
  }

  private func sendVideoEvent(adUnitId: String, eventName: String, payload: [String: Any]) {
    channel?.invokeMethod("videoEvent", arguments: [
      "adUnitId": adUnitId,
      "eventName": eventName,
      "payload": payload,
    ])
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard
        let args = call.arguments as? [String: Any],
        let integrationKey = args["integrationKey"] as? String,
        !integrationKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "integrationKey is required", details: nil))
        return
      }
      let cfg = SSPSDKConfig(
        integrationKey: integrationKey,
        propertyId: args["propertyId"] as? String,
        propertyCode: args["propertyCode"] as? String
      )
      if let baseUrl = args["baseUrl"] as? String, !baseUrl.isEmpty {
        cfg.baseURL = baseUrl
      }
      if let debug = args["debug"] as? Bool {
        cfg.debug = debug
      }
      SSPSDK.shared.initialize(with: cfg)
      result(nil)
    case "setUserData":
      let args = call.arguments as? [String: Any]
      let userData = (args?["userData"] as? [String: Any]) ?? [:]
      SSPSDK.shared.setUserData(userData)
      result(nil)
    case "setTargetingSignals":
      let args = call.arguments as? [String: Any]
      let m = (args?["signals"] as? [String: Any]) ?? [:]
      let interests = (m["interests"] as? [String]) ?? []
      let keywords = (m["keywords"] as? [String]) ?? []
      let segments = (m["segments"] as? [String]) ?? []
      let signals = TargetingSignals(
        userPid: (m["userPid"] as? String) ?? (m["user_pid"] as? String),
        devicePid: (m["devicePid"] as? String) ?? (m["device_pid"] as? String),
        gender: m["gender"] as? String,
        age: m["age"] as? Int,
        dateOfBirth: (m["dateOfBirth"] as? String) ?? (m["date_of_birth"] as? String) ?? (m["dob"] as? String),
        yob: m["yob"] as? Int,
        geoCountry: (m["geoCountry"] as? String) ?? (m["geo_country"] as? String),
        geoRegion: (m["geoRegion"] as? String) ?? (m["geo_region"] as? String),
        interests: interests,
        keywords: keywords,
        segments: segments,
        connectionType: (m["connectionType"] as? String) ?? (m["connection_type"] as? String),
        contentCategory: (m["contentCategory"] as? String) ?? (m["content_category"] as? String),
        pageType: (m["pageType"] as? String) ?? (m["page_type"] as? String)
      )
      SSPSDK.shared.setTargetingSignals(signals)
      result(nil)
    case "syncFirstPartyProfile":
      let bundle = (call.arguments as? [String: Any])?["appBundle"] as? String
      SSPSDK.shared.syncFirstPartyProfile(appBundle: bundle) { syncResult in
        switch syncResult {
        case .success: result(nil)
        case .failure(let err):
          result(FlutterError(code: "FPD_SYNC_FAILED", message: err.localizedDescription, details: nil))
        }
      }
    case "setConsent":
      let args = call.arguments as? [String: Any]
      var consent = ConsentData()
      consent.gdpr = (args?["gdpr"] as? Bool) ?? false
      consent.ccpa = (args?["ccpa"] as? Bool) ?? false
      consent.consentString = args?["consentString"] as? String
      consent.gppString = args?["gppString"] as? String
      consent.gppSid = args?["gppSid"] as? String
      consent.usPrivacyString = args?["usPrivacyString"] as? String
      if let att = args?["attStatus"] as? Int { consent.attStatus = att }
      SSPSDK.shared.setConsent(consent)
      result(nil)
    case "clearIdentifiers":
      SSPSDK.shared.clearIdentifiers()
      result(nil)
    case "registerAdUnit":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      let formatRaw = (args["format"] as? String) ?? "banner"
      let format: AdFormat = {
        switch formatRaw.lowercased() {
        case "interstitial": return .interstitial
        case "native": return .native
        case "video": return .video
        case "rewarded": return .rewarded
        case "audio": return .audio
        default: return .banner
        }
      }()
      let sizeMaps = (args["sizes"] as? [[String: Any]]) ?? []
      let sizes = sizeMaps.compactMap { m -> CGSize? in
        guard let w = m["width"] as? NSNumber, let h = m["height"] as? NSNumber else { return nil }
        return CGSize(width: w.doubleValue, height: h.doubleValue)
      }
      SSPSDK.shared.registerAdUnit(code: adUnitId, format: format, sizes: sizes)
      result(nil)
    case "loadNative":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 320
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 50
      SSPSDK.shared.loadAd(
        code: adUnitId,
        format: .native,
        sizes: [CGSize(width: width, height: height)],
        placementCode: args["placementCode"] as? String,
        placementContext: args["placementContext"] as? String
      ) { [weak self] loadResult in
        guard let self else { return }
        switch loadResult {
        case .success(let response):
          if let ad = response.ad {
            var payload = self.adPayload(from: ad, success: response.success, reason: response.reason, requestId: response.requestId, dsp: response.dsp, price: response.price?.doubleValue)
            let assets = ad.nativeAssets
            payload["headline"] = assets.headline as Any
            payload["body"] = assets.body as Any
            payload["callToAction"] = assets.callToAction as Any
            payload["advertiser"] = assets.advertiser as Any
            payload["iconUrl"] = assets.iconUrl as Any
            result(payload)
          } else {
            result(["success": response.success, "reason": response.reason as Any])
          }
        case .failure(let error):
          result(["success": false, "reason": error.localizedDescription])
        }
      }
    case "loadBanner":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 300
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 250
      let placementCode = args["placementCode"] as? String
      let placementContext = args["placementContext"] as? String
      SSPSDK.shared.loadAd(
        code: adUnitId,
        format: .banner,
        sizes: [CGSize(width: width, height: height)],
        placementCode: placementCode,
        placementContext: placementContext
      ) { loadResult in
        switch loadResult {
        case .success(let response):
          if let ad = response.ad {
            result(self.adPayload(
              from: ad,
              success: response.success,
              reason: response.reason,
              requestId: response.requestId,
              dsp: response.dsp,
              price: response.price
            ))
          } else {
            result([
              "success": response.success,
              "reason": response.reason as Any,
              "requestId": response.requestId as Any,
            ])
          }
        case .failure(let error):
          result([
            "success": false,
            "reason": "network_error",
            "error": error.localizedDescription,
          ])
        }
      }
    case "loadInterstitial":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 320
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 480
      let placementCode = args["placementCode"] as? String
      let placementContext = args["placementContext"] as? String
      var request = DKMadsAdRequest()
      request.placementCode = placementCode
      request.placementContext = placementContext
      DKMadsInterstitialAd.load(
        adUnitID: adUnitId,
        adSize: CGSize(width: width, height: height),
        request: request
      ) { [weak self] interstitial, error in
        guard let self else { return }
        if let error {
          result([
            "success": false,
            "reason": error.localizedDescription,
          ])
          return
        }
        guard let interstitial, let ad = interstitial.loadedAd else {
          result(["success": false, "reason": "no_fill"])
          return
        }
        self.interstitials[adUnitId] = interstitial
        result(self.adPayload(
          from: ad,
          success: ad.hasFill,
          reason: "won",
          requestId: interstitial.responseInfo?.requestId,
          dsp: interstitial.responseInfo?.dsp,
          price: interstitial.responseInfo?.price?.doubleValue
        ))
      }
    case "showInterstitial":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      guard let interstitial = interstitials[adUnitId], interstitial.loadedAd != nil else {
        result(FlutterError(code: "NOT_LOADED", message: "Call loadInterstitial first", details: nil))
        return
      }
      guard let root = topViewController() else {
        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
        return
      }
      interstitial.present(from: root)
      result(nil)
    case "loadAppOpen":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      var request = DKMadsAdRequest()
      request.placementCode = args["placementCode"] as? String
      request.placementContext = args["placementContext"] as? String
      DKMadsAppOpenAd.load(adUnitID: adUnitId, request: request) { [weak self] appOpen, error in
        guard let self else { return }
        if let error {
          result(["success": false, "reason": error.localizedDescription])
          return
        }
        guard let appOpen, let ad = appOpen.loadedAd else {
          result(["success": false, "reason": "no_fill"])
          return
        }
        self.appOpenAds[adUnitId] = appOpen
        result(self.adPayload(
          from: ad,
          success: ad.hasFill,
          reason: "won",
          requestId: appOpen.responseInfo?.requestId,
          dsp: appOpen.responseInfo?.dsp,
          price: appOpen.responseInfo?.price?.doubleValue
        ))
      }
    case "showAppOpen":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      guard let appOpen = appOpenAds[adUnitId], appOpen.loadedAd != nil else {
        result(FlutterError(code: "NOT_LOADED", message: "Call loadAppOpen first", details: nil))
        return
      }
      guard let root = topViewController() else {
        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
        return
      }
      appOpen.present(from: root)
      result(nil)
    case "presentAdInspector":
      guard let root = topViewController() else {
        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
        return
      }
      DKMadsMobileAds.shared.presentAdInspector(from: root)
      result(nil)
    case "loadRewarded":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 320
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 480
      var request = DKMadsAdRequest()
      request.placementCode = args["placementCode"] as? String
      request.placementContext = args["placementContext"] as? String
      let rewarded = DKMadsRewardedAd(adUnitID: adUnitId)
      rewarded.load(request: request, adSize: CGSize(width: width, height: height)) { [weak self] adObj, error in
        guard let self else { return }
        if let error {
          result(["success": false, "reason": error.localizedDescription])
          return
        }
        guard let adObj, let ad = adObj.loadedAd else {
          result(["success": false, "reason": "no_fill"])
          return
        }
        self.rewardedAds[adUnitId] = adObj
        result(self.adPayload(
          from: ad,
          success: ad.hasFill,
          reason: "won",
          requestId: adObj.responseInfo?.requestId,
          dsp: adObj.responseInfo?.dsp,
          price: adObj.responseInfo?.price?.doubleValue
        ))
      }
    case "showRewarded":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      guard let rewarded = rewardedAds[adUnitId], rewarded.loadedAd != nil else {
        result(FlutterError(code: "NOT_LOADED", message: "Call loadRewarded first", details: nil))
        return
      }
      guard let root = topViewController() else {
        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
        return
      }
      rewarded.delegate = self
      rewarded.present(from: root)
      result(nil)
    case "trackUserEvent":
      guard
        let args = call.arguments as? [String: Any],
        let name = args["name"] as? String,
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "name is required", details: nil))
        return
      }
      let attributes = (args["attributes"] as? [String: Any]) ?? [:]
      SSPSDK.shared.trackUserEvent(name: name, attributes: attributes)
      result(nil)
    case "trackVideoLifecycle":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        !adUnitId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId is required", details: nil))
        return
      }
      activeVideoUnits.insert(adUnitId)
      sendVideoEvent(
        adUnitId: adUnitId,
        eventName: "lifecycle_tracking_started",
        payload: ["source": "flutter_ios_plugin"]
      )
      result(nil)
    case "emitVideoEvent":
      guard
        let args = call.arguments as? [String: Any],
        let adUnitId = args["adUnitId"] as? String,
        let eventName = args["eventName"] as? String,
        !adUnitId.isEmpty,
        !eventName.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "adUnitId and eventName are required", details: nil))
        return
      }
      guard activeVideoUnits.contains(adUnitId) else {
        result(FlutterError(code: "NOT_TRACKING", message: "trackVideoLifecycle must be called first for this adUnitId", details: nil))
        return
      }
      var payload = (args["payload"] as? [String: Any]) ?? [:]
      payload["ad_unit_id"] = adUnitId
      TelemetryManager.shared.trackEvent(type: eventName, data: payload)
      sendVideoEvent(adUnitId: adUnitId, eventName: eventName, payload: payload)
      result(nil)
    case "stopVideoLifecycleTracking":
      if let args = call.arguments as? [String: Any], let adUnitId = args["adUnitId"] as? String, !adUnitId.isEmpty {
        activeVideoUnits.remove(adUnitId)
        SSPSDK.shared.stopVideoLifecycleTracking(adUnitId: adUnitId)
        sendVideoEvent(
          adUnitId: adUnitId,
          eventName: "lifecycle_tracking_stopped",
          payload: ["source": "flutter_ios_plugin"]
        )
      }
      result(nil)
    case "requestInstreamAds":
      let args = call.arguments as? [String: Any]
      guard
        let viewId = args?["viewId"] as? Int,
        let adUnitId = args?["adUnitId"] as? String,
        !adUnitId.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "viewId and adUnitId are required", details: nil))
        return
      }
      guard let view = InstreamPlatformRegistry.shared.get(viewId: Int64(viewId)) else {
        result(FlutterError(code: "NOT_FOUND", message: "Instream platform view not ready", details: nil))
        return
      }
      view.requestAds(
        adUnitId: adUnitId,
        width: args?["width"] as? Int ?? 640,
        height: args?["height"] as? Int ?? 360,
        placementContext: args?["placementContext"] as? String
      )
      result(nil)
    case "destroyInstream":
      let args = call.arguments as? [String: Any]
      if let viewId = args?["viewId"] as? Int {
        InstreamPlatformRegistry.shared.get(viewId: Int64(viewId))?.destroyLoader()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension DkmadsSspPlugin: DKMadsRewardedAdDelegate {
  public func rewardedAdDidDismiss(_ ad: DKMadsRewardedAd) {
    channel?.invokeMethod("rewardedEvent", arguments: ["adUnitId": ad.adUnitID, "event": "dismissed"])
  }

  public func rewardedAdDidEarnReward(_ ad: DKMadsRewardedAd) {
    channel?.invokeMethod("rewardedEvent", arguments: ["adUnitId": ad.adUnitID, "event": "earned_reward"])
  }

  public func rewardedAd(_ ad: DKMadsRewardedAd, didFailToReceiveAdWithError error: Error) {
    channel?.invokeMethod("rewardedEvent", arguments: [
      "adUnitId": ad.adUnitID,
      "event": "failed",
      "reason": error.localizedDescription,
    ])
  }
}
