import Foundation
import UIKit

@objc public protocol DKMadsRewardedAdDelegate: AnyObject {
    @objc optional func rewardedAdDidReceiveAd(_ ad: DKMadsRewardedAd)
    @objc optional func rewardedAd(_ ad: DKMadsRewardedAd, didFailToReceiveAdWithError error: Error)
    @objc optional func rewardedAdDidPresent(_ ad: DKMadsRewardedAd)
    @objc optional func rewardedAdDidDismiss(_ ad: DKMadsRewardedAd)
    @objc optional func rewardedAdDidEarnReward(_ ad: DKMadsRewardedAd)
}

/// Production rewarded presenter: reward is granted only on full completion (not skip/close).
@objc(DKMadsRewardedAd)
public final class DKMadsRewardedAd: NSObject, DKMadsFullScreenPresenting {
    @objc public weak var delegate: DKMadsRewardedAdDelegate?
    @objc public weak var fullScreenContentDelegate: DKMadsFullScreenContentDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?
    private var loadedAt: Date?

    private var presenter: DKMadsRewardedPresenter?

    @objc public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    @objc public func load(
        request: DKMadsAdRequest? = nil,
        adSize: CGSize? = nil,
        completion: ((DKMadsRewardedAd?, Error?) -> Void)? = nil
    ) {
        guard SSPSDK.shared.isSDKInitialized else {
            let err = DKMadsAdError.notInitialized.nsError()
            delegate?.rewardedAd?(self, didFailToReceiveAdWithError: err)
            completion?(nil, err)
            return
        }
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .rewarded,
            sizes: adSize != nil ? [adSize!] : [CGSize(width: 320, height: 480)],
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
                    self.delegate?.rewardedAd?(self, didFailToReceiveAdWithError: err)
                    completion?(nil, err)
                    return
                }
                self.loadedAd = ad
                self.loadedAt = Date()
                self.delegate?.rewardedAdDidReceiveAd?(self)
                completion?(self, nil)
            case .failure(let error):
                self.delegate?.rewardedAd?(self, didFailToReceiveAdWithError: error)
                completion?(nil, error)
            }
        }
    }

    @objc public func present(from rootViewController: UIViewController) {
        guard let loadedAd else {
            delegate?.rewardedAd?(self, didFailToReceiveAdWithError: DKMadsAdError.noFill.nsError())
            return
        }
        if DKMadsAdCachePolicy.isExpired(loadedAt: loadedAt, format: .rewarded) {
            let err = DKMadsAdError.adExpired.nsError()
            delegate?.rewardedAd?(self, didFailToReceiveAdWithError: err)
            fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: err)
            return
        }
        let vc = DKMadsRewardedPresenter(adUnitID: adUnitID, ad: loadedAd)
        vc.onDismiss = { [weak self] in
            guard let self else { return }
            self.presenter = nil
            self.delegate?.rewardedAdDidDismiss?(self)
            self.fullScreenContentDelegate?.adDidDismissFullScreenContent?(self)
        }
        vc.onFailed = { [weak self] error in
            guard let self else { return }
            self.presenter = nil
            self.delegate?.rewardedAd?(self, didFailToReceiveAdWithError: error)
            self.fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: error)
        }
        vc.onReward = { [weak self] in
            guard let self else { return }
            self.delegate?.rewardedAdDidEarnReward?(self)
        }
        presenter = vc
        fullScreenContentDelegate?.adWillPresentFullScreenContent?(self)
        rootViewController.present(vc, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.rewardedAdDidPresent?(self)
        }
    }
}

private final class DKMadsRewardedPresenter: UIViewController, DKMadsVideoAdViewDelegate {
    let adUnitID: String
    let ad: Ad
    var onDismiss: (() -> Void)?
    var onFailed: ((Error) -> Void)?
    var onReward: (() -> Void)?
    private var rewarded = false

    init(adUnitID: String, ad: Ad) {
        self.adUnitID = adUnitID
        self.ad = ad
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let video = DKMadsVideoAdView(adUnitID: adUnitID, frame: view.bounds)
        video.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        video.rootViewController = self
        video.isSkippable = ad.skippable?.boolValue ?? true
        video.skipOffsetSeconds = ad.skipAfterSec?.doubleValue ?? 5
        video.delegate = self
        view.addSubview(video)
        video.display(ad)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            onDismiss?()
        }
    }

    func videoAdViewDidComplete(_ videoAdView: DKMadsVideoAdView) {
        rewarded = true
        onReward?()
        dismiss(animated: true)
    }

    func videoAdViewDidSkip(_ videoAdView: DKMadsVideoAdView) {
        dismiss(animated: true)
    }

    func videoAdView(_ videoAdView: DKMadsVideoAdView, didFailToReceiveAdWithError error: Error) {
        onFailed?(error)
        dismiss(animated: true)
    }
}
