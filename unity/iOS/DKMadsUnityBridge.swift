import Foundation
import UIKit

private var pendingInterstitialAds: [String: Ad] = [:]
private var pendingInterstitialInstances: [String: DKMadsInterstitialAd] = [:]
private var pendingRewardedAds: [String: DKMadsRewardedAd] = [:]

@_cdecl("dkmads_initialize")
public func dkmads_initialize(_ integrationKeyPtr: UnsafePointer<CChar>?,
                              _ propertyIdPtr: UnsafePointer<CChar>?,
                              _ propertyCodePtr: UnsafePointer<CChar>?) {
  guard let integrationKeyPtr else { return }
  let integrationKey = String(cString: integrationKeyPtr)
  let propertyId = propertyIdPtr.map { String(cString: $0) }
  let propertyCode = propertyCodePtr.map { String(cString: $0) }
  let cfg = SSPSDKConfig(integrationKey: integrationKey, propertyId: propertyId, propertyCode: propertyCode)
  SSPSDK.shared.initialize(with: cfg)
}

@_cdecl("dkmads_set_user_data")
public func dkmads_set_user_data(_ jsonPayloadPtr: UnsafePointer<CChar>?) {
  let payload = parseJsonDictionary(jsonPayloadPtr)
  SSPSDK.shared.setUserData(payload)
}

@_cdecl("dkmads_set_targeting_signals")
public func dkmads_set_targeting_signals(_ jsonPayloadPtr: UnsafePointer<CChar>?) {
  let payload = parseJsonDictionary(jsonPayloadPtr)
  func str(_ key: String) -> String? {
    guard let v = payload[key] as? String, !v.isEmpty else { return nil }
    return v
  }
  func int(_ key: String) -> Int? {
    if let n = payload[key] as? Int { return n }
    if let n = payload[key] as? Double { return Int(n) }
    if let s = payload[key] as? String, let n = Int(s) { return n }
    return nil
  }
  func strings(_ key: String) -> [String] {
    if let arr = payload[key] as? [String] { return arr }
    if let arr = payload[key] as? [Any] { return arr.compactMap { $0 as? String } }
    return []
  }
  let signals = TargetingSignals(
    userPid: str("user_pid") ?? str("userPid"),
    devicePid: str("device_pid") ?? str("devicePid"),
    gender: str("gender"),
    age: int("age"),
    dateOfBirth: str("date_of_birth") ?? str("dateOfBirth") ?? str("dob"),
    yob: int("yob"),
    geoCountry: str("geo_country") ?? str("geoCountry"),
    geoRegion: str("geo_region") ?? str("geoRegion"),
    interests: strings("interests"),
    keywords: strings("keywords"),
    segments: strings("segments"),
    connectionType: str("connection_type") ?? str("connectionType"),
    contentCategory: str("content_category") ?? str("contentCategory"),
    pageType: str("page_type") ?? str("pageType")
  )
  SSPSDK.shared.setTargetingSignals(signals)
}

@_cdecl("dkmads_set_consent")
public func dkmads_set_consent(_ jsonPayloadPtr: UnsafePointer<CChar>?) {
  let payload = parseJsonDictionary(jsonPayloadPtr)
  func str(_ key: String) -> String? {
    guard let v = payload[key] as? String, !v.isEmpty else { return nil }
    return v
  }
  func bool(_ key: String) -> Bool {
    payload[key] as? Bool ?? false
  }
  func intOpt(_ key: String) -> Int? {
    if let n = payload[key] as? Int { return n }
    if let n = payload[key] as? Double { return Int(n) }
    if let s = payload[key] as? String, let n = Int(s) { return n }
    return nil
  }
  var consent = ConsentData(
    gdpr: bool("gdpr"),
    ccpa: bool("ccpa"),
    consentString: str("consentString") ?? str("consent_string"),
    gppString: str("gppString") ?? str("gpp_string"),
    gppSid: str("gppSid") ?? str("gpp_sid"),
    usPrivacyString: str("usPrivacyString") ?? str("us_privacy_string"),
    attStatus: intOpt("attStatus") ?? intOpt("att_status")
  )
  SSPSDK.shared.setConsent(consent)
}

@_cdecl("dkmads_track_user_event")
public func dkmads_track_user_event(_ namePtr: UnsafePointer<CChar>?,
                                    _ jsonPayloadPtr: UnsafePointer<CChar>?) {
  guard let namePtr else { return }
  let name = String(cString: namePtr)
  let payload = parseJsonDictionary(jsonPayloadPtr)
  SSPSDK.shared.trackUserEvent(name: name, attributes: payload)
}

@_cdecl("dkmads_emit_video_event")
public func dkmads_emit_video_event(_ adUnitIdPtr: UnsafePointer<CChar>?,
                                    _ eventNamePtr: UnsafePointer<CChar>?,
                                    _ jsonPayloadPtr: UnsafePointer<CChar>?) {
  guard let adUnitIdPtr, let eventNamePtr else { return }
  let adUnitId = String(cString: adUnitIdPtr)
  let eventName = String(cString: eventNamePtr)
  var payload = parseJsonDictionary(jsonPayloadPtr)
  payload["ad_unit_id"] = adUnitId
  TelemetryManager.shared.trackEvent(type: eventName, data: payload)
}

/// Returns JSON string with success, reason, adm, video_url, etc.
@_cdecl("dkmads_load_ad")
public func dkmads_load_ad(_ adUnitIdPtr: UnsafePointer<CChar>?,
                           _ formatPtr: UnsafePointer<CChar>?,
                           _ width: Int32,
                           _ height: Int32) -> UnsafeMutablePointer<CChar>? {
  guard let adUnitIdPtr else { return strdup("{\"success\":false,\"reason\":\"invalid_args\"}") }
  let adUnitId = String(cString: adUnitIdPtr)
  let formatRaw = formatPtr.map { String(cString: $0) } ?? "banner"
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
  let w = CGFloat(max(1, Int(width)))
  let h = CGFloat(max(1, Int(height)))
  let sizes: [CGSize] = format == .interstitial
    ? (w > 0 && h > 0 ? [CGSize(width: w, height: h)] : [])
    : [CGSize(width: w, height: h)]
  var jsonOut = "{\"success\":false,\"reason\":\"pending\"}"
  let sem = DispatchSemaphore(value: 0)
  SSPSDK.shared.loadAd(
    code: adUnitId,
    format: format,
    sizes: sizes.isEmpty && format == .interstitial
      ? [CGSize(width: 320, height: 480)]
      : sizes
  ) { result in
    switch result {
    case .success(let response):
      if format == .interstitial, let ad = response.ad, ad.hasFill {
        pendingInterstitialAds[adUnitId] = ad
      }
      jsonOut = adResponseToJson(response)
    case .failure(let err):
      jsonOut = "{\"success\":false,\"reason\":\"network_error\",\"error\":\"\(err.localizedDescription.replacingOccurrences(of: "\"", with: "'"))\"}"
    }
    sem.signal()
  }
  _ = sem.wait(timeout: .now() + 30)
  return strdup(jsonOut)
}

@_cdecl("dkmads_load_interstitial")
public func dkmads_load_interstitial(_ adUnitIdPtr: UnsafePointer<CChar>?,
                                     _ width: Int32,
                                     _ height: Int32) -> UnsafeMutablePointer<CChar>? {
  guard let adUnitIdPtr else { return strdup("{\"success\":false,\"reason\":\"invalid_args\"}") }
  let adUnitId = String(cString: adUnitIdPtr)
  let w = CGFloat(max(1, Int(width)))
  let h = CGFloat(max(1, Int(height)))
  var jsonOut = "{\"success\":false,\"reason\":\"pending\"}"
  let sem = DispatchSemaphore(value: 0)
  DKMadsInterstitialAd.load(
    adUnitID: adUnitId,
    adSize: CGSize(width: w, height: h)
  ) { interstitial, error in
    if let error {
      jsonOut = "{\"success\":false,\"reason\":\"\(error.localizedDescription.replacingOccurrences(of: "\"", with: "'"))\"}"
    } else if let interstitial, let ad = interstitial.loadedAd, ad.hasFill {
      pendingInterstitialInstances[adUnitId] = interstitial
      pendingInterstitialAds[adUnitId] = ad
      jsonOut = adToJson(ad, responseInfo: interstitial.responseInfo)
    } else {
      jsonOut = "{\"success\":false,\"reason\":\"no_fill\"}"
    }
    sem.signal()
  }
  _ = sem.wait(timeout: .now() + 30)
  return strdup(jsonOut)
}

@_cdecl("dkmads_show_interstitial")
public func dkmads_show_interstitial(_ adUnitIdPtr: UnsafePointer<CChar>?) {
  guard let adUnitIdPtr else { return }
  let adUnitId = String(cString: adUnitIdPtr)
  guard let interstitial = pendingInterstitialInstances[adUnitId] else { return }
  DispatchQueue.main.async {
    guard let root = topViewController() else { return }
    interstitial.present(from: root)
  }
}

@_cdecl("dkmads_load_rewarded")
public func dkmads_load_rewarded(_ adUnitIdPtr: UnsafePointer<CChar>?,
                                 _ width: Int32,
                                 _ height: Int32) -> UnsafeMutablePointer<CChar>? {
  guard let adUnitIdPtr else { return strdup("{\"success\":false,\"reason\":\"invalid_args\"}") }
  let adUnitId = String(cString: adUnitIdPtr)
  let w = CGFloat(max(1, Int(width)))
  let h = CGFloat(max(1, Int(height)))
  let rewarded = DKMadsRewardedAd(adUnitID: adUnitId)
  var jsonOut = "{\"success\":false,\"reason\":\"pending\"}"
  let sem = DispatchSemaphore(value: 0)
  rewarded.load(adSize: CGSize(width: w, height: h)) { adObj, error in
    if let error {
      jsonOut = "{\"success\":false,\"reason\":\"\(error.localizedDescription.replacingOccurrences(of: "\"", with: "'"))\"}"
    } else if let adObj, let ad = adObj.loadedAd, ad.hasFill {
      pendingRewardedAds[adUnitId] = adObj
      jsonOut = adToJson(ad, responseInfo: adObj.responseInfo)
    } else {
      jsonOut = "{\"success\":false,\"reason\":\"no_fill\"}"
    }
    sem.signal()
  }
  _ = sem.wait(timeout: .now() + 30)
  return strdup(jsonOut)
}

@_cdecl("dkmads_show_rewarded")
public func dkmads_show_rewarded(_ adUnitIdPtr: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
  guard let adUnitIdPtr else { return strdup("{\"success\":false,\"reason\":\"invalid_args\"}") }
  let adUnitId = String(cString: adUnitIdPtr)
  guard let rewarded = pendingRewardedAds[adUnitId] else { return strdup("{\"success\":false,\"reason\":\"not_loaded\"}") }
  DispatchQueue.main.async {
    guard let root = topViewController() else { return }
    rewarded.present(from: root)
  }
  return strdup("{\"success\":true}")
}

private func topViewController() -> UIViewController? {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
  guard var top = window?.rootViewController else { return nil }
  while let presented = top.presentedViewController { top = presented }
  return top
}

private func adResponseToJson(_ response: AdResponse) -> String {
  guard let ad = response.ad else {
    return "{\"success\":\(response.success),\"reason\":\"\(response.reason ?? "no_fill")\"}"
  }
  return adToJson(ad, responseInfo: response.responseInfo)
}

private func adToJson(_ ad: Ad, responseInfo: DKMadsResponseInfo?) -> String {
  var parts: [String] = [
    "\"success\":\(ad.hasFill)",
    "\"adId\":\"\(escapeJson(ad.id))\"",
    "\"adm\":\"\(escapeJson(ad.adm ?? ""))\"",
    "\"creativeUrl\":\"\(escapeJson(ad.creativeUrl))\"",
    "\"clickUrl\":\"\(escapeJson(ad.clickUrl))\"",
    "\"videoUrl\":\"\(escapeJson(ad.videoUrl ?? ""))\"",
    "\"html5EntryUrl\":\"\(escapeJson(ad.html5EntryUrl ?? ""))\"",
    "\"width\":\(ad.width)",
    "\"height\":\(ad.height)",
    "\"isVideo\":\(ad.isVideo)",
    "\"isHtml5\":\(ad.isHTML5)",
    "\"campaignId\":\"\(escapeJson(ad.campaignId ?? ""))\"",
    "\"creativeId\":\"\(escapeJson(ad.creativeId ?? ""))\"",
    "\"videoTemplate\":\"\(escapeJson(ad.videoTemplate ?? ""))\"",
    "\"ctaLabel\":\"\(escapeJson(ad.ctaLabel))\"",
    "\"ctaPosition\":\"\(escapeJson(ad.ctaPosition ?? ""))\"",
    "\"companionImageUrl\":\"\(escapeJson(ad.companionImageUrl ?? ""))\"",
    "\"showCompanionClick\":\(ad.showCompanionClick?.boolValue == true ? "true" : "false")",
    "\"skippable\":\(ad.skippable?.boolValue == true ? "true" : "false")",
    "\"skipAfterSec\":\(ad.skipAfterSec?.doubleValue ?? 0)",
    "\"unitFormat\":\"\(escapeJson(ad.unitFormat ?? ""))\"",
    "\"placementContext\":\"\(escapeJson(ad.placementContext ?? ""))\"",
  ]
  if let reason = responseInfo?.reason { parts.append("\"reason\":\"\(escapeJson(reason))\"") }
  if let requestId = responseInfo?.requestId { parts.append("\"requestId\":\"\(escapeJson(requestId))\"") }
  if let dsp = responseInfo?.dsp { parts.append("\"dsp\":\"\(escapeJson(dsp))\"") }
  if let price = responseInfo?.price { parts.append("\"price\":\(price.doubleValue)") }
  return "{\(parts.joined(separator: ","))}"
}

private func escapeJson(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
}

@_cdecl("dkmads_free_string")
public func dkmads_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
  if let ptr { free(ptr) }
}

private func parseJsonDictionary(_ ptr: UnsafePointer<CChar>?) -> [String: Any] {
  guard let ptr else { return [:] }
  let text = String(cString: ptr)
  guard let data = text.data(using: .utf8) else { return [:] }
  guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
  return json
}
