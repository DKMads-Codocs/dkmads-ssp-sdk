import Foundation

public struct ConsentData {
    public var gdpr: Bool = false
    public var ccpa: Bool = false
    public var consentString: String?
    public var gppString: String?
    public var gppSid: String?

    public init(
        gdpr: Bool = false,
        ccpa: Bool = false,
        consentString: String? = nil,
        gppString: String? = nil,
        gppSid: String? = nil
    ) {
        self.gdpr = gdpr
        self.ccpa = ccpa
        self.consentString = consentString
        self.gppString = gppString
        self.gppSid = gppSid
    }
}

public typealias UserData = [String: Any]
