import Foundation

/// Unified fullscreen callbacks (interstitial, rewarded, app-open style).
@objc public protocol DKMadsFullScreenContentDelegate: AnyObject {
    @objc optional func adWillPresentFullScreenContent(_ presenting: DKMadsFullScreenPresenting)
    @objc optional func adDidDismissFullScreenContent(_ presenting: DKMadsFullScreenPresenting)
    @objc optional func ad(
        _ presenting: DKMadsFullScreenPresenting,
        didFailToPresentFullScreenContentWithError error: Error
    )
    @objc optional func adDidRecordImpression(_ presenting: DKMadsFullScreenPresenting)
    @objc optional func adDidRecordClick(_ presenting: DKMadsFullScreenPresenting)
}

@objc public protocol DKMadsFullScreenPresenting: AnyObject {
    @objc var adUnitID: String { get }
    @objc var responseInfo: DKMadsResponseInfo? { get }
}
