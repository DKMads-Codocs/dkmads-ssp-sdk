import Foundation

@objc public class SSPSDKConfig: NSObject {
    @objc public var integrationKey: String
    @objc public var propertyId: String?
    @objc public var propertyCode: String?
    @objc public var debug: Bool = false
    /// Enables verbose logging and `debug: true` on bid requests. Pair with dashboard test ad units for predictable fills.
    @objc public var useTestAds: Bool = false {
        didSet { if useTestAds { debug = true } }
    }
    @objc public var timeout: TimeInterval = 10.0
    @objc public var baseURL: String = "https://ssp.dkmads.com"
    /// When true, ad requests are blocked until setConsent is called.
    @objc public var requireConsentBeforeAds: Bool = false

    @objc public init(integrationKey: String, propertyId: String? = nil, propertyCode: String? = nil) {
        self.integrationKey = integrationKey
        self.propertyId = propertyId
        self.propertyCode = propertyCode
    }
}
