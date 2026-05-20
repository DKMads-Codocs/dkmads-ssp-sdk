import AVFoundation
import Foundation
import SafariServices
import UIKit
import WebKit

@objc public protocol DKMadsVideoAdViewDelegate: AnyObject {
    @objc optional func videoAdViewDidReceiveAd(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdView(_ videoAdView: DKMadsVideoAdView, didFailToReceiveAdWithError error: Error)
    @objc optional func videoAdViewDidStartPlayback(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidComplete(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordClick(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordImpression(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordViewableImpression(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidSkip(_ videoAdView: DKMadsVideoAdView)
}

/// Drop-in video / instream view (AdMob-style). Loads, renders MP4 or HTML video `adm`, and tracks lifecycle.
@objc public final class DKMadsVideoAdView: UIView {
    @objc public weak var delegate: DKMadsVideoAdViewDelegate?
    @objc public weak var rootViewController: UIViewController?

    @objc public var adUnitID: String
    @objc public var autoplay = true
    /// When true, shows a Skip control after `skipOffsetSeconds` (instream / interstitial chrome).
    @objc public var isSkippable = true
    @objc public var skipOffsetSeconds: TimeInterval = 5
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private let webBridge = AdVideoWebPlaybackBridge()
    private let webView: WKWebView
    private let playerView = UIView()
    private let player = AVPlayer()
    private var playerLayer: AVPlayerLayer?
    private var skipButton: UIButton?
    private var skipTimer: Timer?
    private var isLoading = false
    private var viewabilityActive = false
    private var videoEventsAttached = false
    private var webPlaybackStarted = false
    private var webPlaybackCompleted = false

    @objc public init(adUnitID: String, frame: CGRect = .zero) {
        self.adUnitID = adUnitID
        let config = AdVideoPlayback.makeWebViewConfiguration(bridge: webBridge)
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frame)
        webBridge.onComplete = { [weak self] in
            self?.handleWebPlaybackComplete()
        }
        setupViews()
    }

    required init?(coder: NSCoder) {
        self.adUnitID = ""
        let config = AdVideoPlayback.makeWebViewConfiguration(bridge: webBridge)
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(coder: coder)
        webBridge.onComplete = { [weak self] in
            self?.handleWebPlaybackComplete()
        }
        setupViews()
    }

    /// Renders an ad already returned from `SSPSDK.loadAd` (e.g. interstitial preload).
    @objc public func display(_ ad: Ad) {
        stopPlayback()
        guard ad.isVideo, ad.preferredPlaybackURL != nil || !(ad.adm?.isEmpty ?? true) else {
            delegate?.videoAdView?(self, didFailToReceiveAdWithError: DKMadsAdError.missingVideoURL.nsError())
            return
        }
        loadedAd = ad
        render(ad: ad)
        delegate?.videoAdViewDidReceiveAd?(self)
        delegate?.videoAdViewDidRecordImpression?(self)
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil, adSize: CGSize = CGSize(width: 640, height: 360)) {
        guard !isLoading else { return }
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.videoAdView?(self, didFailToReceiveAdWithError: DKMadsAdError.notInitialized.nsError())
            return
        }
        stopPlayback()
        isLoading = true

        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .video,
            sizes: [adSize],
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                guard response.success, let ad = response.ad, ad.hasFill else {
                    let err = DKMadsAdError.noFill.nsError(userInfo: [
                        NSLocalizedDescriptionKey: response.reason ?? "no_fill",
                    ])
                    self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: err)
                    return
                }
                guard ad.isVideo, ad.preferredPlaybackURL != nil || !(ad.adm?.isEmpty ?? true) else {
                    let err = DKMadsAdError.missingVideoURL.nsError()
                    self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: err)
                    return
                }
                self.loadedAd = ad
                self.render(ad: ad)
                self.delegate?.videoAdViewDidReceiveAd?(self)
                self.delegate?.videoAdViewDidRecordImpression?(self)
            case .failure(let error):
                self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: error)
            }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = playerView.bounds
        if loadedAd != nil, window != nil {
            startViewabilityIfNeeded()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopViewability() }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: AdVideoWebEvents.messageChannel
        )
        stopPlayback()
    }

    private func setupViews() {
        backgroundColor = .black
        clipsToBounds = true

        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.isHidden = true
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        playerView.backgroundColor = .black
        playerView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(playerView)
        addSubview(webView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        playerView.layer.addSublayer(layer)
        playerLayer = layer
    }

    private func render(ad: Ad) {
        webPlaybackStarted = false
        webPlaybackCompleted = false
        switch ad.preferredRenderer {
        case .nativeMP4:
            webView.isHidden = true
            playerView.isHidden = false
            attachVideoTelemetry(skippable: isSkippable)
            scheduleSkipIfNeeded()
            AdVideoPlayback.loadNative(ad: ad, player: player, autoplay: autoplay) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: error)
                    return
                }
                self.delegate?.videoAdViewDidStartPlayback?(self)
            }
        case .webMarkup:
            playerView.isHidden = true
            webView.isHidden = false
            scheduleSkipIfNeeded()
            AdVideoPlayback.loadWebMarkup(ad: ad, in: webView, autoplay: autoplay)
        }
    }

    private func attachVideoTelemetry(skippable: Bool) {
        guard !videoEventsAttached else { return }
        videoEventsAttached = true
        SSPSDK.shared.trackVideoLifecycle(
            adUnitId: adUnitID,
            campaignId: loadedAd?.campaignId,
            creativeId: loadedAd?.creativeId,
            player: player,
            containerView: self,
            skippable: skippable
        ) { [weak self] event, _ in
            guard let self else { return }
            if event == "video_start" {
                self.delegate?.videoAdViewDidStartPlayback?(self)
            }
            if event == "video_100" {
                self.completePlayback(skipped: false)
            }
        }
    }

    private func handleWebPlaybackComplete() {
        completePlayback(skipped: false)
    }

    private func completePlayback(skipped: Bool) {
        guard !webPlaybackCompleted else { return }
        webPlaybackCompleted = true
        cancelSkipTimer()
        skipButton?.removeFromSuperview()
        skipButton = nil
        if skipped {
            delegate?.videoAdViewDidSkip?(self)
        }
        delegate?.videoAdViewDidComplete?(self)
    }

    @objc private func skipTapped() {
        completePlayback(skipped: true)
    }

    private func scheduleSkipIfNeeded() {
        guard isSkippable, skipOffsetSeconds >= 0 else { return }
        cancelSkipTimer()
        skipTimer = Timer.scheduledTimer(withTimeInterval: skipOffsetSeconds, repeats: false) { [weak self] _ in
            self?.showSkipButton()
        }
    }

    private func showSkipButton() {
        guard isSkippable, skipButton == nil else { return }
        let button = UIButton(type: .system)
        button.setTitle("Skip", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
        skipButton = button
    }

    private func cancelSkipTimer() {
        skipTimer?.invalidate()
        skipTimer = nil
    }

    private func stopPlayback() {
        stopViewability()
        cancelSkipTimer()
        skipButton?.removeFromSuperview()
        skipButton = nil
        if videoEventsAttached {
            SSPSDK.shared.stopVideoLifecycleTracking(adUnitId: adUnitID)
            videoEventsAttached = false
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        webView.loadHTMLString("", baseURL: nil)
        webView.isHidden = true
        playerView.isHidden = true
        loadedAd = nil
        webPlaybackStarted = false
        webPlaybackCompleted = false
    }

    private func startViewabilityIfNeeded() {
        guard loadedAd != nil, window != nil, !viewabilityActive, bounds.width > 0 else { return }
        viewabilityActive = true
        SSPSDK.shared.attachBannerViewability(
            adUnitId: adUnitID,
            containerView: self,
            creativeId: loadedAd?.id
        ) { [weak self] in
            guard let self else { return }
            self.delegate?.videoAdViewDidRecordViewableImpression?(self)
        }
    }

    private func stopViewability() {
        if viewabilityActive {
            SSPSDK.shared.detachBannerViewability(adUnitId: adUnitID)
            viewabilityActive = false
        }
    }
}

extension DKMadsVideoAdView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        AdVideoPlayback.injectVideoEndDetection(in: webView)
        if !webPlaybackStarted {
            webPlaybackStarted = true
            delegate?.videoAdViewDidStartPlayback?(self)
        }
        startViewabilityIfNeeded()
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if AdVideoPlayback.isAdCompleteNavigation(navigationAction.request.url) {
            handleWebPlaybackComplete()
            decisionHandler(.cancel)
            return
        }
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            recordClick()
            rootViewController?.present(SFSafariViewController(url: url), animated: true)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func recordClick() {
        guard let ad = loadedAd else { return }
        SSPSDK.shared.recordAdClick(
            adId: ad.id,
            adUnitId: adUnitID,
            campaignId: ad.campaignId,
            creativeId: ad.creativeId,
            dspSource: ad.dsp
        )
        delegate?.videoAdViewDidRecordClick?(self)
    }
}
