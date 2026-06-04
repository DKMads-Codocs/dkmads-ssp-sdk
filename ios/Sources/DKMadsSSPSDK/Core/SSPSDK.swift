import Foundation
import UIKit
import AVFoundation

@objc public class SSPSDK: NSObject {
    @objc public static let shared = SSPSDK()

    private var config: SSPSDKConfig?
    private var userData: UserData = [:]
    private var targetingSignals = TargetingSignals()
    private var consent = ConsentData()
    private var consentConfigured = false
    private var adUnits: [String: AdUnit] = [:]
    private var sdkInitialized = false
    @objc public private(set) var lastBidDiagnostics: DKMadsBidDiagnostics?

    private override init() {
        super.init()
    }

    @objc public var isSDKInitialized: Bool { sdkInitialized }
    @objc public var isDebugEnabled: Bool { config?.debug == true }

    @objc public func initialize(with config: SSPSDKConfig) {
        self.config = config
        let defaultDevicePid = DeviceIdentity.getOrCreateDevicePid()
        if (targetingSignals.devicePid ?? "").isEmpty {
            targetingSignals.devicePid = defaultDevicePid
        }
        TelemetryManager.shared.configure(with: config)
        refreshCmpConsent()
        TelemetryManager.shared.setIdentityProvider { [weak self] in
            guard let self else { return [:] }
            var ids: [String: String?] = [
                "user_pid": (self.userData["user_pid"] as? String) ?? self.targetingSignals.userPid,
                "device_pid": (self.userData["device_pid"] as? String)
                    ?? self.targetingSignals.devicePid
                    ?? defaultDevicePid,
                "platform_uid": (self.userData["platform_uid"] as? String) ?? PlatformIdentity.get(),
            ]
            if self.consent.allowsAdvertisingId() {
                ids["idfa"] = (self.userData["idfa"] as? String) ?? AdvertisingIdentifiers.idfa()
            }
            return ids
        }

        let deviceInfo = DeviceDetector.getDeviceInfo()
        TelemetryManager.shared.trackEvent(
            type: "sdk_init",
            data: [
                "platform": "ios",
                "sdkVersion": SDK_VERSION,
                "deviceType": deviceInfo.type,
            ]
        )

        sdkInitialized = true
        log("SDK initialized")
    }

    @objc public func canRequestAds() -> Bool {
        guard sdkInitialized else { return false }
        if config?.requireConsentBeforeAds == true {
            return consentConfigured
        }
        return true
    }

    public func loadAd(
        code: String,
        format: AdFormat,
        sizes: [CGSize] = [],
        placementCode: String? = nil,
        placementContext: String? = nil,
        keyValues: [String: Any] = [:],
        completion: @escaping (Result<AdResponse, Error>) -> Void
    ) {
        guard let config else {
            completion(.failure(SDKError.notInitialized))
            return
        }
        if !canRequestAds() {
            completion(.failure(SDKError.invalidConfig))
            return
        }
        refreshCmpConsent()

        let request = AdRequest(
            adUnitId: code,
            format: format,
            sizes: sizes,
            placementCode: placementCode,
            placementContext: placementContext,
            keyValues: keyValues,
            userData: userData,
            targetingSignals: targetingSignals,
            device: DeviceDetector.getDeviceInfo(),
            consent: consent,
            debug: config.debug
        )

        TelemetryManager.shared.trackEvent(
            type: "ad_request",
            data: [
                "adUnitCode": code,
                "format": format.apiValue,
                "placement_code": placementCode as Any,
                "placement_context": placementContext as Any,
            ]
        )

        let started = Date()
        APIClient.shared.request(
            endpoint: PublicAPIPaths.bidURL(baseURL: config.baseURL),
            method: .post,
            integrationKey: config.integrationKey,
            timeout: config.timeout,
            debug: config.debug,
            body: request.toDictionary()
        ) { [weak self] result in
            let deliver: (Result<AdResponse, Error>) -> Void = { outcome in
                DispatchQueue.main.async { completion(outcome) }
            }
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            switch result {
            case .success(let http):
                let reason = http.json["reason"] as? String
                let requestId = http.json["request_id"] as? String
                let refreshSec = http.json["refresh_interval_sec"] as? Int
                if let adData = http.json["winner"] as? [String: Any], !adData.isEmpty {
                    let parsedAd = Ad(from: adData)
                    let dsp = adData["dsp"] as? String
                    let price = adData["price"] as? Double
                    let response = AdResponse(
                        success: parsedAd.hasFill,
                        ad: parsedAd,
                        reason: reason ?? "won",
                        requestId: requestId,
                        dsp: dsp,
                        price: price,
                        latencyMs: latency,
                        refreshIntervalSec: refreshSec
                    )
                    self?.recordBidDiagnostics(
                        adUnitId: code,
                        format: format.apiValue,
                        response: response,
                        latencyMs: latency,
                        refreshIntervalSec: refreshSec
                    )
                    deliver(.success(response))
                } else {
                    let response = AdResponse(
                        success: false,
                        reason: reason,
                        requestId: requestId,
                        latencyMs: latency,
                        refreshIntervalSec: refreshSec
                    )
                    self?.recordBidDiagnostics(
                        adUnitId: code,
                        format: format.apiValue,
                        response: response,
                        latencyMs: latency,
                        refreshIntervalSec: refreshSec
                    )
                    deliver(.success(response))
                }
            case .failure(let error):
                self?.trackError(event: "ad_request", error: error)
                self?.recordBidDiagnostics(
                    adUnitId: code,
                    format: format.apiValue,
                    response: nil,
                    latencyMs: latency,
                    errorMessage: error.localizedDescription
                )
                deliver(.failure(error))
            }
        }
    }

    public func trackUserEvent(name: String, attributes: [String: Any] = [:]) {
        var payload: [String: Any] = [
            "event_name": name,
            "source": "app",
            "property_id": config?.propertyId as Any,
            "attributes": attributes,
            "os": "ios",
        ]
        if let devicePid = userData["device_pid"] { payload["device_pid"] = devicePid }
        if let userPid = userData["user_pid"] { payload["user_pid"] = userPid }
        TelemetryManager.shared.trackEvent(type: "first_party_signal", data: payload)
    }

    public func trackVideoLifecycle(
        adUnitId: String,
        campaignId: String? = nil,
        creativeId: String? = nil,
        player: AVPlayer,
        containerView: UIView,
        skippable: Bool? = nil,
        eventListener: ((String, [String: Any]) -> Void)? = nil
    ) {
        TelemetryManager.shared.trackVideoAd(
            adUnitId: adUnitId,
            campaignId: campaignId,
            creativeId: creativeId,
            player: player,
            containerView: containerView,
            skippable: skippable,
            eventListener: eventListener
        )
    }

    public func stopVideoLifecycleTracking(adUnitId: String) {
        TelemetryManager.shared.stopVideoTracking(adUnitId: adUnitId)
    }

    public func trackAudioLifecycle(
        adUnitId: String,
        campaignId: String? = nil,
        creativeId: String? = nil,
        player: AVPlayer,
        eventListener: ((String, [String: Any]) -> Void)? = nil
    ) {
        TelemetryManager.shared.trackAudioAd(
            adUnitId: adUnitId,
            campaignId: campaignId,
            creativeId: creativeId,
            player: player,
            eventListener: eventListener
        )
    }

    public func stopAudioLifecycleTracking(adUnitId: String) {
        TelemetryManager.shared.stopAudioTracking(adUnitId: adUnitId)
    }

    private func recordBidDiagnostics(
        adUnitId: String,
        format: String,
        response: AdResponse?,
        latencyMs: Int,
        refreshIntervalSec: Int? = nil,
        errorMessage: String? = nil
    ) {
        lastBidDiagnostics = DKMadsBidDiagnostics(
            adUnitId: adUnitId,
            format: format,
            reason: response?.reason,
            requestId: response?.requestId,
            dsp: response?.dsp,
            price: response?.price?.doubleValue,
            latencyMs: latencyMs,
            refreshIntervalSec: refreshIntervalSec ?? response?.refreshIntervalSec?.intValue,
            loaded: response?.success ?? false,
            errorMessage: errorMessage
        )
    }

    /// IAB viewability helper (default 50% visible for >=1s).
    @objc public func attachBannerViewability(
        adUnitId: String,
        containerView: UIView,
        campaignId: String? = nil,
        creativeId: String? = nil,
        threshold: CGFloat = 0.5,
        minExposureTime: TimeInterval = 1.0,
        onViewable: (() -> Void)? = nil
    ) {
        var extra: [String: Any] = ["ad_unit_id": adUnitId]
        if let campaignId, !campaignId.isEmpty { extra["campaign_id"] = campaignId }
        if let creativeId, !creativeId.isEmpty { extra["creative_id"] = creativeId }
        TelemetryManager.shared.trackViewability(
            adUnitId: adUnitId,
            container: containerView,
            threshold: threshold,
            minExposureTime: minExposureTime,
            extra: extra,
            onViewable: onViewable
        )
    }

    @objc public func detachBannerViewability(adUnitId: String) {
        TelemetryManager.shared.stopViewabilityTracking(adUnitId: adUnitId)
    }

    public func registerAdUnit(code: String, format: AdFormat, sizes: [CGSize] = []) {
        adUnits[code] = AdUnit(code: code, format: format, sizes: sizes)
    }

    public func setUserData(_ data: UserData) {
        userData = data
    }

    public func setTargetingSignals(_ signals: TargetingSignals) {
        targetingSignals = signals
        userData = userData.merging(signals.toUserData()) { _, new in new }
    }

    /// Sync structured profile to `POST /api/public/v1/fpd/mobile` (requires `devicePid`).
    public func syncFirstPartyProfile(appBundle: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let config else {
            completion?(.failure(SDKError.notInitialized))
            return
        }
        let devicePid = targetingSignals.devicePid ?? (userData["device_pid"] as? String)
        guard let devicePid, !devicePid.isEmpty else {
            completion?(.failure(SDKError.invalidConfig))
            return
        }
        var payload = targetingSignals.toFirstPartyPayload(os: "ios", appBundle: appBundle)
        payload["device_pid"] = devicePid
        APIClient.shared.request(
            endpoint: PublicAPIPaths.fpdMobileURL(baseURL: config.baseURL),
            method: .post,
            integrationKey: config.integrationKey,
            timeout: config.timeout,
            debug: config.debug,
            body: payload
        ) { result in
            switch result {
            case .success: completion?(.success(()))
            case .failure(let err): completion?(.failure(err))
            }
        }
    }

    public func setConsent(_ consent: ConsentData) {
        self.consent = consent
        refreshCmpConsent()
        consentConfigured = true
    }

    private func refreshCmpConsent() {
        consent = CmpConsent.merge(into: consent)
        if CmpConsent.hasMinimalConsent(consent) {
            consentConfigured = true
        }
        TelemetryManager.shared.setConsent(consent)
    }

    public func clearIdentifiers() {
        userData["user_pid"] = nil
        userData["device_pid"] = nil
    }

    @objc public func recordAdClick(
        adId: String,
        adUnitId: String? = nil,
        campaignId: String? = nil,
        creativeId: String? = nil,
        dspSource: String? = nil
    ) {
        var data: [String: Any] = ["adId": adId]
        if let adUnitId, !adUnitId.isEmpty { data["ad_unit_id"] = adUnitId }
        if let campaignId, !campaignId.isEmpty { data["campaign_id"] = campaignId }
        if let creativeId, !creativeId.isEmpty { data["creative_id"] = creativeId }
        if let dspSource, !dspSource.isEmpty { data["dsp_source"] = dspSource }
        TelemetryManager.shared.trackEvent(type: "ad_click", data: data)
    }

    public func trackEvent(name: String, data: [String: Any] = [:]) {
        TelemetryManager.shared.trackEvent(type: name, data: data)
    }

    @objc public func recordAdImpression(
        adUnitId: String,
        adId: String,
        campaignId: String? = nil,
        creativeId: String? = nil,
        dspSource: String? = nil
    ) {
        var data: [String: Any] = ["ad_unit_id": adUnitId, "adId": adId]
        if let campaignId, !campaignId.isEmpty { data["campaign_id"] = campaignId }
        if let creativeId, !creativeId.isEmpty { data["creative_id"] = creativeId }
        if let dspSource, !dspSource.isEmpty { data["dsp_source"] = dspSource }
        TelemetryManager.shared.trackEvent(type: "ad_impression", data: data)
    }

    private func trackError(event: String, error: Error) {
        TelemetryManager.shared.trackEvent(type: event, data: ["error": error.localizedDescription])
    }

    private func log(_ message: String) {
        if config?.debug == true {
            print("[DKMads SSP] \(message)")
        }
    }
}
