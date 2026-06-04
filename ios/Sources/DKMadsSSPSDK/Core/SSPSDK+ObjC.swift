import Foundation

/// ObjC-friendly entry points for mixed Swift/ObjC apps.
extension SSPSDK {
    @objc public func setConsentGdpr(
        _ gdpr: Bool,
        consentString: String?,
        usPrivacy: String?,
        gppString: String?,
        gppSid: NSNumber?
    ) {
        var consent = ConsentData()
        consent.gdpr = gdpr
        consent.consentString = consentString
        consent.usPrivacyString = usPrivacy
        consent.gppString = gppString
        if let gppSid { consent.gppSid = gppSid.stringValue }
        setConsent(consent)
    }

    @objc(loadAdWithCode:format:width:height:placementCode:placementContext:completion:)
    public func loadAdObjC(
        code: String,
        format: AdFormat,
        width: CGFloat,
        height: CGFloat,
        placementCode: String?,
        placementContext: String?,
        completion: @escaping (AdResponse?, NSError?) -> Void
    ) {
        let sizes: [CGSize] = (width > 0 && height > 0) ? [CGSize(width: width, height: height)] : []
        loadAd(
            code: code,
            format: format,
            sizes: sizes,
            placementCode: placementCode,
            placementContext: placementContext,
            keyValues: [:]
        ) { result in
            switch result {
            case .success(let response):
                completion(response, nil)
            case .failure(let error):
                completion(nil, error as NSError)
            }
        }
    }

    @objc(syncFirstPartyProfileWithAppBundle:completion:)
    public func syncFirstPartyProfileObjC(
        appBundle: String?,
        completion: ((NSError?) -> Void)?
    ) {
        syncFirstPartyProfile(appBundle: appBundle) { result in
            switch result {
            case .success: completion?(nil)
            case .failure(let err): completion?(err as NSError)
            }
        }
    }

    @objc(setTargetingSignalsFromDictionary:)
    public func setTargetingSignalsObjC(_ dictionary: [String: Any]) {
        var signals = TargetingSignals()
        func str(_ key: String) -> String? {
            guard let v = dictionary[key] as? String, !v.isEmpty else { return nil }
            return v
        }
        func int(_ key: String) -> Int? {
            if let n = dictionary[key] as? Int { return n }
            if let n = dictionary[key] as? NSNumber { return n.intValue }
            return nil
        }
        func strings(_ key: String) -> [String] {
            (dictionary[key] as? [String]) ?? []
        }
        signals.userPid = str("user_pid")
        signals.devicePid = str("device_pid")
        signals.gender = str("gender")
        signals.age = int("age")
        signals.dateOfBirth = str("date_of_birth")
        signals.yob = int("yob")
        signals.geoCountry = str("geo_country")
        signals.geoRegion = str("geo_region")
        signals.interests = strings("interests")
        signals.keywords = strings("keywords")
        signals.segments = strings("segments")
        signals.connectionType = str("connection_type")
        signals.contentCategory = str("content_category")
        signals.pageType = str("page_type")
        setTargetingSignals(signals)
    }
}
