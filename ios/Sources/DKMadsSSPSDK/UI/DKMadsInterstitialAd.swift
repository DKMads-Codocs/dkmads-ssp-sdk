import Foundation
import UIKit

@objc public protocol DKMadsInterstitialAdDelegate: AnyObject {
    @objc optional func interstitialAdDidReceiveAd(_ ad: DKMadsInterstitialAd)
    @objc optional func interstitialAd(_ ad: DKMadsInterstitialAd, didFailToReceiveAdWithError error: Error)
    @objc optional func interstitialAdDidPresent(_ ad: DKMadsInterstitialAd)
    @objc optional func interstitialAdDidDismiss(_ ad: DKMadsInterstitialAd)
}

/// Fullscreen interstitial (video, image, HTML5, or tag). Use for dashboard format `interstitial`.
@objc(DKMadsInterstitialAd)
public final class DKMadsInterstitialAd: NSObject, DKMadsFullScreenPresenting {
    @objc public weak var delegate: DKMadsInterstitialAdDelegate?
    @objc public weak var fullScreenContentDelegate: DKMadsFullScreenContentDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?
    private var loadedAt: Date?

    private var presenter: DKMadsInterstitialPresenter?

    private var lastAdRequest: DKMadsAdRequest?

    @objc public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    /// Loads an interstitial ad. Swift API (`load` avoids ObjC `+load` selector clash).
    public static func load(
        adUnitID: String,
        adSize: CGSize? = nil,
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsInterstitialAd?, Error?) -> Void
    ) {
        DKMadsInterstitialAd(adUnitID: adUnitID).load(adSize: adSize, request: request, completion: completion)
    }

    /// ObjC entry point — do not name `load` (reserved `+load` on `NSObject`).
    @objc(loadInterstitialWithAdUnitID:request:completion:)
    public static func loadInterstitial(
        adUnitID: String,
        request: DKMadsAdRequest?,
        completion: @escaping (DKMadsInterstitialAd?, Error?) -> Void
    ) {
        load(adUnitID: adUnitID, adSize: nil, request: request, completion: completion)
    }

    @objc(loadInterstitialWithAdUnitID:adWidth:adHeight:request:completion:)
    public static func loadInterstitial(
        adUnitID: String,
        adWidth: CGFloat,
        adHeight: CGFloat,
        request: DKMadsAdRequest?,
        completion: @escaping (DKMadsInterstitialAd?, Error?) -> Void
    ) {
        let size = (adWidth > 0 && adHeight > 0) ? CGSize(width: adWidth, height: adHeight) : nil
        load(adUnitID: adUnitID, adSize: size, request: request, completion: completion)
    }

    public func load(
        adSize: CGSize? = nil,
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsInterstitialAd?, Error?) -> Void
    ) {
        if let request { lastAdRequest = request }
        let effectiveRequest = request ?? lastAdRequest
        guard SSPSDK.shared.isSDKInitialized else {
            completion(nil, DKMadsAdError.notInitialized.nsError())
            return
        }
        let bidSizes = Self.bidSizes(adUnitID: adUnitID, adSize: adSize)
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .interstitial,
            sizes: bidSizes,
            placementCode: effectiveRequest?.placementCode,
            placementContext: effectiveRequest?.placementContext,
            keyValues: effectiveRequest?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                guard response.success, let ad = response.ad, ad.hasFill else {
                    let err = DKMadsAdError.noFill.nsError(userInfo: [
                        NSLocalizedDescriptionKey: response.reason ?? "no_fill",
                    ])
                    self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: err)
                    completion(nil, err)
                    return
                }
                self.loadedAd = ad
                self.loadedAt = Date()
                self.delegate?.interstitialAdDidReceiveAd?(self)
                completion(self, nil)
            case .failure(let error):
                self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: error)
                completion(nil, error)
            }
        }
    }

    /// IAB interstitial tokens for bid matching — not raw UIScreen pixel dimensions.
    static func bidSizes(adUnitID: String, adSize: CGSize?) -> [CGSize] {
        if let adSize, adSize.width > 0, adSize.height > 0 {
            return [adSize]
        }
        let registered = SSPSDK.shared.registeredSizes(for: adUnitID)
        if !registered.isEmpty {
            return registered
        }
        return [CGSize(width: 320, height: 480)]
    }

    @objc(presentFromRootViewController:)
    public func present(from rootViewController: UIViewController) {
        guard let loadedAd else {
            delegate?.interstitialAd?(self, didFailToReceiveAdWithError: DKMadsAdError.noFill.nsError())
            return
        }
        if DKMadsAdCachePolicy.isExpired(loadedAt: loadedAt, format: .interstitial) {
            let err = DKMadsAdError.adExpired.nsError()
            delegate?.interstitialAd?(self, didFailToReceiveAdWithError: err)
            fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: err)
            return
        }
        let vc = DKMadsInterstitialPresenter(adUnitID: adUnitID, ad: loadedAd)
        vc.onDismiss = { [weak self] in
            guard let self else { return }
            self.presenter = nil
            self.delegate?.interstitialAdDidDismiss?(self)
            self.fullScreenContentDelegate?.adDidDismissFullScreenContent?(self)
        }
        vc.onPlaybackComplete = { [weak self] in
            self?.presenter?.dismiss(animated: true)
        }
        vc.onRenderFailed = { [weak self] error in
            guard let self else { return }
            self.presenter = nil
            rootViewController.dismiss(animated: true)
            self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: error)
            self.fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: error)
        }
        presenter = vc
        fullScreenContentDelegate?.adWillPresentFullScreenContent?(self)
        rootViewController.present(vc, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.interstitialAdDidPresent?(self)
        }
    }
}
