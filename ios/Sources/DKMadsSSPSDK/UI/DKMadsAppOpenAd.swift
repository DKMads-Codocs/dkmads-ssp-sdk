import Foundation
import UIKit

@objc public protocol DKMadsAppOpenAdDelegate: AnyObject {
    @objc optional func appOpenAdDidReceiveAd(_ ad: DKMadsAppOpenAd)
    @objc optional func appOpenAd(_ ad: DKMadsAppOpenAd, didFailToReceiveAdWithError error: Error)
    @objc optional func appOpenAdDidPresent(_ ad: DKMadsAppOpenAd)
    @objc optional func appOpenAdDidDismiss(_ ad: DKMadsAppOpenAd)
}

/// App open / splash fullscreen ad (dashboard format `splash`). Show on cold start or resume.
@objc(DKMadsAppOpenAd)
public final class DKMadsAppOpenAd: NSObject, DKMadsFullScreenPresenting {
    @objc public weak var delegate: DKMadsAppOpenAdDelegate?
    @objc public weak var fullScreenContentDelegate: DKMadsFullScreenContentDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?
    private var loadedAt: Date?

    private var presenter: DKMadsInterstitialPresenter?

    @objc public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public static func load(
        adUnitID: String,
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsAppOpenAd?, Error?) -> Void
    ) {
        DKMadsAppOpenAd(adUnitID: adUnitID).load(request: request, completion: completion)
    }

    @objc(loadAppOpenWithAdUnitID:request:completion:)
    public static func loadAppOpen(
        adUnitID: String,
        request: DKMadsAdRequest?,
        completion: @escaping (DKMadsAppOpenAd?, Error?) -> Void
    ) {
        load(adUnitID: adUnitID, request: request, completion: completion)
    }

    public func load(
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsAppOpenAd?, Error?) -> Void
    ) {
        guard SSPSDK.shared.isSDKInitialized else {
            let err = DKMadsAdError.notInitialized.nsError()
            delegate?.appOpenAd?(self, didFailToReceiveAdWithError: err)
            completion(nil, err)
            return
        }
        let bidSizes = DKMadsInterstitialAd.bidSizes(adUnitID: adUnitID, adSize: nil)
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .splash,
            sizes: bidSizes,
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                guard response.success, let ad = response.ad, ad.hasFill else {
                    let err = DKMadsAdError.noFill.nsError(userInfo: [
                        NSLocalizedDescriptionKey: response.reason ?? "no_fill",
                    ])
                    self.delegate?.appOpenAd?(self, didFailToReceiveAdWithError: err)
                    completion(nil, err)
                    return
                }
                self.loadedAd = ad
                self.loadedAt = Date()
                self.delegate?.appOpenAdDidReceiveAd?(self)
                completion(self, nil)
            case .failure(let error):
                self.delegate?.appOpenAd?(self, didFailToReceiveAdWithError: error)
                completion(nil, error)
            }
        }
    }

    @objc(presentFromRootViewController:)
    public func present(from rootViewController: UIViewController) {
        guard let loadedAd else {
            delegate?.appOpenAd?(self, didFailToReceiveAdWithError: DKMadsAdError.noFill.nsError())
            return
        }
        if DKMadsAdCachePolicy.isExpired(loadedAt: loadedAt, format: .splash) {
            let err = DKMadsAdError.adExpired.nsError()
            delegate?.appOpenAd?(self, didFailToReceiveAdWithError: err)
            fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: err)
            return
        }
        let vc = DKMadsInterstitialPresenter(adUnitID: adUnitID, ad: loadedAd)
        vc.onDismiss = { [weak self] in
            guard let self else { return }
            self.presenter = nil
            self.delegate?.appOpenAdDidDismiss?(self)
            self.fullScreenContentDelegate?.adDidDismissFullScreenContent?(self)
        }
        vc.onPlaybackComplete = { [weak self] in
            self?.presenter?.dismiss(animated: true)
        }
        vc.onRenderFailed = { [weak self] error in
            guard let self else { return }
            self.presenter = nil
            rootViewController.dismiss(animated: true)
            self.delegate?.appOpenAd?(self, didFailToReceiveAdWithError: error)
            self.fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: error)
        }
        presenter = vc
        fullScreenContentDelegate?.adWillPresentFullScreenContent?(self)
        rootViewController.present(vc, animated: true) { [weak self] in
            self?.delegate?.appOpenAdDidPresent?(self!)
        }
    }
}
