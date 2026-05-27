import Foundation

public struct ConsentData {
    public var gdpr: Bool = false
    public var ccpa: Bool = false
    public var consentString: String?
    public var gppString: String?
    public var gppSid: String?
    /// IAB US Privacy string (USP v1), e.g. "1YNN". Prefer CMP-provided value over boolean defaults.
    public var usPrivacyString: String?
    /// iOS ATT status: 0=notDetermined, 1=restricted, 2=denied, 3=authorized
    public var attStatus: Int?

    public init(
        gdpr: Bool = false,
        ccpa: Bool = false,
        consentString: String? = nil,
        gppString: String? = nil,
        gppSid: String? = nil,
        usPrivacyString: String? = nil,
        attStatus: Int? = nil
    ) {
        self.gdpr = gdpr
        self.ccpa = ccpa
        self.consentString = consentString
        self.gppString = gppString
        self.gppSid = gppSid
        self.usPrivacyString = usPrivacyString
        self.attStatus = attStatus
    }

    func resolvedUsPrivacyString() -> String? {
        let s = usPrivacyString?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    /// Gate IDFA on bid/events — mirrors Android GAID policy + iOS ATT.
    func allowsAdvertisingId() -> Bool {
        if gdpr {
            let cs = consentString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if cs.isEmpty { return false }
        }
        if let usp = resolvedUsPrivacyString(), usp.count >= 3 {
            let idx = usp.index(usp.startIndex, offsetBy: 2)
            if usp[idx] == "Y" { return false }
        }
        let att = attStatus ?? AdvertisingIdentifiers.attStatus()
        if let att, att != 3 { return false }
        return true
    }
}

public typealias UserData = [String: Any]
