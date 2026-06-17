import Foundation
import UIKit
import WebKit

/// Open Measurement (OMID) verification resource, parsed from the bid winner
/// (`winner.omid_verifications` / VAST `<AdVerifications>`).
@objc public final class DKMadsOmidVerification: NSObject {
    @objc public let vendorKey: String
    @objc public let javascriptResourceURL: String
    @objc public let verificationParameters: String?

    @objc public init(vendorKey: String, javascriptResourceURL: String, verificationParameters: String?) {
        self.vendorKey = vendorKey
        self.javascriptResourceURL = javascriptResourceURL
        self.verificationParameters = verificationParameters
    }
}

/// Active OMID measurement session. Implemented by an OM SDK adapter; the SDK
/// core only calls these lifecycle signals at the right moments.
@objc public protocol DKMadsOmidSession {
    func start()
    func signalLoaded()
    func signalImpression()
    @objc optional func signalVideoStart(duration: Float, volume: Float)
    @objc optional func signalVideoFirstQuartile()
    @objc optional func signalVideoMidpoint()
    @objc optional func signalVideoThirdQuartile()
    @objc optional func signalVideoComplete()
    @objc optional func signalVideoPaused()
    @objc optional func signalVideoResumed()
    @objc optional func signalVideoSkipped()
    func finish()
}

/// Pluggable OMID provider. Apps that integrate the IAB OM SDK register a real
/// implementation via `DKMadsOmid.provider`; otherwise OMID is a no-op and the
/// SDK falls back to first-party MRC-style viewability telemetry.
@objc public protocol DKMadsOmidProvider {
    var partnerName: String { get }
    var partnerVersion: String { get }
    var isActive: Bool { get }

    /// HTML/display session over a creative `webView`.
    func createHtmlDisplaySession(webView: WKWebView) -> DKMadsOmidSession?

    /// Native display session over an `adView` with verification resources.
    func createNativeDisplaySession(adView: UIView, verifications: [DKMadsOmidVerification]) -> DKMadsOmidSession?

    /// Video session over a player `adView` with verification resources.
    func createVideoSession(adView: UIView, verifications: [DKMadsOmidVerification]) -> DKMadsOmidSession?
}

/// Global OMID registry. Set `provider` once at app start when the OM SDK is present.
@objc public final class DKMadsOmid: NSObject {
    @objc public static var provider: DKMadsOmidProvider?

    @objc public static var isAvailable: Bool {
        provider?.isActive == true
    }
}
