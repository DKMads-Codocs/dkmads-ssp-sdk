import AVFoundation
import Foundation
import UIKit

@objc public protocol DKMadsInstreamAdsLoaderDelegate: AnyObject {
    @objc optional func instreamAdsLoaderDidStartAd(_ loader: DKMadsInstreamAdsLoader)
    @objc optional func instreamAdsLoaderDidFinishAd(_ loader: DKMadsInstreamAdsLoader)
    @objc optional func instreamAdsLoader(_ loader: DKMadsInstreamAdsLoader, didFailWithError error: Error)
}

/// IMA-style instream coordinator: pauses content, plays ad in container, optionally resumes content.
@objc public final class DKMadsInstreamAdsLoader: NSObject {
    @objc public weak var delegate: DKMadsInstreamAdsLoaderDelegate?
    @objc public var pauseContentAutomatically = true
    @objc public var resumeContentAfterAd = true
    /// When true (default), removes the internal video view and hides `adContainer` after the ad ends or fails.
    @objc public var hidesAdContainerWhenFinished = true

    /// Last filled ad from the internal `DKMadsVideoAdView` (read after `instreamAdsLoaderDidStartAd`).
    @objc public private(set) var loadedAd: Ad?
    /// Bid diagnostics for analytics — same request as the instream ad (no second bid needed).
    @objc public private(set) var responseInfo: DKMadsResponseInfo?

    private weak var contentPlayer: AVPlayer?
    private weak var adContainer: UIView?
    private var onPauseContent: (() -> Void)?
    private var onResumeContent: (() -> Void)?
    private var videoAdView: DKMadsVideoAdView?
    private var contentWasPlaying = false
    private var didPauseContentForAd = false
    private var savedContentTime: CMTime?

    @objc public init(contentPlayer: AVPlayer, adContainer: UIView) {
        self.contentPlayer = contentPlayer
        self.adContainer = adContainer
        super.init()
    }

    /// Flutter / custom players: pause and resume via host callbacks instead of [AVPlayer].
    @objc public init(
        adContainer: UIView,
        onPauseContent: @escaping () -> Void,
        onResumeContent: @escaping () -> Void
    ) {
        self.adContainer = adContainer
        self.onPauseContent = onPauseContent
        self.onResumeContent = onResumeContent
        super.init()
    }

    @objc public func requestAds(
        adUnitID: String,
        contentPosition: String? = nil,
        adSize: CGSize = CGSize(width: 640, height: 360)
    ) {
        guard let adContainer else {
            delegate?.instreamAdsLoader?(self, didFailWithError: DKMadsAdError.invalidConfig.nsError())
            return
        }

        loadedAd = nil
        responseInfo = nil
        videoAdView?.removeFromSuperview()
        let view = DKMadsVideoAdView(adUnitID: adUnitID, frame: adContainer.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.autoplay = true
        view.rootViewController = adContainer.dkmadsOwningViewController()
        view.delegate = self
        adContainer.addSubview(view)
        videoAdView = view

        didPauseContentForAd = false
        savedContentTime = nil
        adContainer.isHidden = false
        if pauseContentAutomatically {
            if let contentPlayer {
                contentWasPlaying = contentPlayer.rate > 0
                savedContentTime = contentPlayer.currentTime()
                contentPlayer.pause()
                didPauseContentForAd = true
            } else if let onPauseContent {
                onPauseContent()
                didPauseContentForAd = true
            }
        }

        let request = DKMadsAdRequest()
        request.placementContext = contentPosition
        view.load(request, adSize: adSize)
    }

    @objc public func destroy() {
        clearAdOverlay(resetAnalytics: true)
    }

    private func clearAdOverlay(resetAnalytics: Bool) {
        videoAdView?.removeFromSuperview()
        videoAdView = nil
        if hidesAdContainerWhenFinished {
            adContainer?.isHidden = true
        }
        if resetAnalytics {
            loadedAd = nil
            responseInfo = nil
        }
    }

    private func syncFromVideoAdView() {
        loadedAd = videoAdView?.loadedAd
        responseInfo = videoAdView?.responseInfo
    }

    private func resumeContentIfNeeded() {
        guard resumeContentAfterAd else { return }
        if let contentPlayer {
            let shouldResume = didPauseContentForAd || contentWasPlaying
            guard shouldResume else { return }
            if let saved = savedContentTime, saved.isValid, !saved.isIndefinite {
                contentPlayer.seek(to: saved, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            contentPlayer.play()
            didPauseContentForAd = false
            contentWasPlaying = false
            savedContentTime = nil
            return
        }
        if didPauseContentForAd, let onResumeContent {
            onResumeContent()
            didPauseContentForAd = false
        }
    }
}

private extension UIView {
    func dkmadsOwningViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}

extension DKMadsInstreamAdsLoader: DKMadsVideoAdViewDelegate {
    public func videoAdViewDidReceiveAd(_ videoAdView: DKMadsVideoAdView) {
        syncFromVideoAdView()
        delegate?.instreamAdsLoaderDidStartAd?(self)
    }

    public func videoAdView(_ videoAdView: DKMadsVideoAdView, didFailToReceiveAdWithError error: Error) {
        syncFromVideoAdView()
        clearAdOverlay(resetAnalytics: false)
        resumeContentIfNeeded()
        delegate?.instreamAdsLoader?(self, didFailWithError: error)
    }

    public func videoAdViewDidComplete(_ videoAdView: DKMadsVideoAdView) {
        syncFromVideoAdView()
        clearAdOverlay(resetAnalytics: false)
        resumeContentIfNeeded()
        delegate?.instreamAdsLoaderDidFinishAd?(self)
    }

    public func videoAdViewDidSkip(_ videoAdView: DKMadsVideoAdView) {
        syncFromVideoAdView()
        clearAdOverlay(resetAnalytics: false)
        resumeContentIfNeeded()
        delegate?.instreamAdsLoaderDidFinishAd?(self)
    }

    public func videoAdViewDidStartPlayback(_ videoAdView: DKMadsVideoAdView) {
        syncFromVideoAdView()
        delegate?.instreamAdsLoaderDidStartAd?(self)
    }
}
