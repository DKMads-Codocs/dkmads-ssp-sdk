import AVFoundation
import Foundation
import SafariServices
import UIKit
import WebKit

@objc public protocol DKMadsVideoAdViewDelegate: AnyObject {
    @objc optional func videoAdViewDidReceiveAd(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdView(_ videoAdView: DKMadsVideoAdView, didFailToReceiveAdWithError error: Error)
    @objc optional func videoAdViewDidStartPlayback(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidStartBuffering(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidEndBuffering(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidComplete(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordClick(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordImpression(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidRecordViewableImpression(_ videoAdView: DKMadsVideoAdView)
    @objc optional func videoAdViewDidSkip(_ videoAdView: DKMadsVideoAdView)
}

/// Drop-in video / instream view. Loads, renders MP4 or HTML video `adm`, and tracks lifecycle.
@objc public final class DKMadsVideoAdView: UIView {
    @objc public weak var delegate: DKMadsVideoAdViewDelegate?
    @objc public weak var rootViewController: UIViewController?

    @objc public var adUnitID: String
    @objc public var autoplay = true
    /// When true, shows a Skip control after `skipOffsetSeconds` (instream / interstitial chrome).
    @objc public var isSkippable = true
    @objc public var skipOffsetSeconds: TimeInterval = 5
    /// Fullscreen interstitial: scale native video to fill bounds (`.resizeAspectFill`).
    @objc public var prefersAspectFill = false
    /// Wrap HTML `adm` in a fullscreen viewport shell (interstitial / app open).
    @objc public var wrapsWebMarkupForFullscreen = false
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private let webBridge = AdVideoWebPlaybackBridge()
    private let webView: WKWebView
    private let playerView = UIView()
    private let player = AVPlayer()
    private var playerLayer: AVPlayerLayer?
    private var skipButton: UIButton?
    private var muteButton: UIButton?
    private var clickOverlay: UIView?
    private var ctaButton: UIButton?
    private var companionImageView: UIImageView?
    private var skipTimer: Timer?
    private var isPlaybackMuted = true
    private var isLoading = false
    private var loadGeneration: UInt = 0
    private var lastRequestedPlacementContext: String?
    private var lastBidVideoSize: CGSize = CGSize(width: 640, height: 360)
    private var lastVideoRenderSize: CGSize = CGSize(width: 640, height: 360)
    private var viewabilityActive = false
    private var videoEventsAttached = false
    private var webPlaybackStarted = false
    private var webPlaybackCompleted = false
    private var nativePlaybackHandle: AdNativePlaybackHandle?
    private var omidSession: DKMadsOmidSession?
    private var blurBackground: DKMadsVideoBlurBackground?

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
        loadGeneration &+= 1
        isLoading = false
        stopPlayback()
        guard ad.hasVideoRenderableContent else {
            delegate?.videoAdView?(self, didFailToReceiveAdWithError: DKMadsAdError.missingVideoURL.nsError())
            return
        }
        loadedAd = ad
        applySkipConfig(from: ad)
        render(ad: ad)
        if !ad.impressionRecorded {
            SSPSDK.shared.recordAdImpression(
                adUnitId: adUnitID,
                adId: ad.id,
                campaignId: ad.campaignId,
                creativeId: ad.creativeId,
                dspSource: ad.dsp
            )
            ad.impressionRecorded = true
        }
        delegate?.videoAdViewDidReceiveAd?(self)
        delegate?.videoAdViewDidRecordImpression?(self)
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil, adSize: CGSize = CGSize(width: 640, height: 360), bidSize: CGSize = .zero) {
        guard !isLoading else { return }
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.videoAdView?(self, didFailToReceiveAdWithError: DKMadsAdError.notInitialized.nsError())
            return
        }
        stopPlayback()
        let generation = loadGeneration &+ 1
        loadGeneration = generation
        isLoading = true
        lastRequestedPlacementContext = request?.placementContext
        let bidSizeForRequest = (bidSize.width > 0 && bidSize.height > 0) ? bidSize : adSize
        lastBidVideoSize = bidSizeForRequest

        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .video,
            sizes: [bidSizeForRequest],
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            guard generation == self.loadGeneration else { return }
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
                guard ad.hasVideoRenderableContent else {
                    let err = DKMadsAdError.missingVideoURL.nsError()
                    self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: err)
                    return
                }
                self.loadedAd = ad
                self.applySkipConfig(from: ad)
                self.render(ad: ad)
                SSPSDK.shared.recordAdImpression(
                    adUnitId: self.adUnitID,
                    adId: ad.id,
                    campaignId: ad.campaignId,
                    creativeId: ad.creativeId,
                    dspSource: ad.dsp
                )
                ad.impressionRecorded = true
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
        let useBlur = loadedAd?.usesContainBlurLayout == true
        playerLayer?.videoGravity = (prefersAspectFill && !useBlur) ? .resizeAspectFill : .resizeAspect
        blurBackground?.layoutBlurLayer()
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
        backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
        clipsToBounds = true

        webView.isOpaque = false
        webView.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
        webView.isHidden = true
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        playerView.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
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
        let useBlur = ad.usesContainBlurLayout
        if useBlur {
            playerView.backgroundColor = .clear
            playerLayer?.backgroundColor = UIColor.clear.cgColor
            if blurBackground == nil { blurBackground = DKMadsVideoBlurBackground() }
            blurBackground?.attach(in: self, below: playerView)
        } else {
            blurBackground?.release()
            blurBackground = nil
            playerView.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
            playerLayer?.backgroundColor = UIColor.black.cgColor
        }
        switch ad.preferredRenderer {
        case .nativeMP4:
            webView.isHidden = true
            playerView.isHidden = false
            attachVideoTelemetry(skippable: isSkippable)
            scheduleSkipIfNeeded()
            nativePlaybackHandle?.invalidate()
            nativePlaybackHandle = AdVideoPlayback.loadNative(
                ad: ad,
                player: player,
                autoplay: autoplay,
                onReady: { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: error)
                        return
                    }
                    let muted = DKMadsVideoChrome.defaultPlaybackMuted(
                        unitFormat: ad.unitFormat,
                        placementContext: self.effectivePlacementContext(for: ad),
                        videoTemplate: ad.videoTemplate
                    )
                    self.player.isMuted = muted
                    self.isPlaybackMuted = muted
                    let durationSec = Float(CMTimeGetSeconds(self.player.currentItem?.duration ?? .zero))
                    self.startOmidVideoSession(durationSec: durationSec.isFinite ? durationSec : 0, muted: muted)
                    if useBlur {
                        self.blurBackground?.bind(mainPlayer: self.player)
                    }
                    self.attachVideoClickOverlay(ad: ad)
                    self.attachVideoChrome(ad: ad)
                    self.delegate?.videoAdViewDidStartPlayback?(self)
                    self.attachClickThroughCta(ad: ad)
                    self.attachCompanion(ad: ad)
                },
                onBuffering: { [weak self] buffering in
                    guard let self else { return }
                    if buffering {
                        self.delegate?.videoAdViewDidStartBuffering?(self)
                    } else {
                        self.delegate?.videoAdViewDidEndBuffering?(self)
                    }
                },
                onStallFailed: { [weak self] error in
                    guard let self else { return }
                    self.delegate?.videoAdView?(self, didFailToReceiveAdWithError: error)
                }
            )
        case .webMarkup:
            playerView.isHidden = true
            webView.isHidden = false
            scheduleSkipIfNeeded()
            if wrapsWebMarkupForFullscreen, let adm = ad.adm, !adm.isEmpty {
                let slot = bounds.width > 0 && bounds.height > 0
                    ? bounds.size
                    : CGSize(width: 320, height: 480)
                webView.loadHTMLString(
                    DKMadsBannerCreativeLayout.htmlForFullscreen(adm: adm, slotSize: slot),
                    baseURL: AdVideoPlayback.baseURL
                )
            } else if useBlur, let adm = ad.adm, !adm.isEmpty,
                      DKMadsVideoSlotFit.admIncludesBlurStage(adm) {
                webView.loadHTMLString(adm, baseURL: AdVideoPlayback.baseURL)
            } else {
                let stage = DKMadsVideoSlotFit.playerStageSize(
                    containerBounds: bounds.size,
                    bidSize: lastBidVideoSize
                )
                lastVideoRenderSize = stage
                AdVideoPlayback.loadWebMarkup(
                    ad: ad,
                    in: webView,
                    autoplay: autoplay,
                    slotSize: stage,
                    preservePackagedBlur: useBlur
                )
            }
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
            switch event {
            case "video_start":
                self.delegate?.videoAdViewDidStartPlayback?(self)
            case "video_25":
                self.omidSession?.signalVideoFirstQuartile?()
            case "video_50":
                self.omidSession?.signalVideoMidpoint?()
            case "video_75":
                self.omidSession?.signalVideoThirdQuartile?()
            case "video_100":
                self.omidSession?.signalVideoComplete?()
                self.completePlayback(skipped: false)
            default:
                break
            }
        }
    }

    private func startOmidVideoSession(durationSec: Float, muted: Bool) {
        guard omidSession == nil, DKMadsOmid.isAvailable, let ad = loadedAd else { return }
        omidSession = DKMadsOmid.provider?.createVideoSession(adView: self, verifications: ad.omidVerifications)
        omidSession?.start()
        omidSession?.signalLoaded()
        omidSession?.signalVideoStart?(duration: durationSec, volume: muted ? 0 : 1)
    }

    private func handleWebPlaybackComplete() {
        completePlayback(skipped: false)
    }

    private func completePlayback(skipped: Bool) {
        guard !webPlaybackCompleted else { return }
        webPlaybackCompleted = true
        cancelSkipTimer()
        removeVideoChrome()
        removeVideoClickOverlay()
        skipButton?.removeFromSuperview()
        skipButton = nil
        if skipped {
            TelemetryManager.shared.markVideoUserSkipped(adUnitId: adUnitID)
            omidSession?.signalVideoSkipped?()
            emitVideoSkip()
            delegate?.videoAdViewDidSkip?(self)
        }
        player.pause()
        SSPSDK.shared.stopVideoLifecycleTracking(adUnitId: adUnitID)
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
        button.backgroundColor = UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 0.55)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        addSubview(button)
        let bottomInset = DKMadsVideoChrome.chromeBottomInset(
            hasProgress: DKMadsVideoChrome.showsProgress(template: loadedAd?.videoTemplate)
        )
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
        skipButton = button
    }

    private func cancelSkipTimer() {
        skipTimer?.invalidate()
        skipTimer = nil
    }

    private func attachVideoChrome(ad: Ad) {
        removeVideoChrome()
        guard DKMadsVideoChrome.showsMute(template: ad.videoTemplate) else { return }
        let button = DKMadsVideoChrome.makeMuteButton(muted: isPlaybackMuted)
        button.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        addSubview(button)
        let bottomInset = DKMadsVideoChrome.chromeBottomInset(
            hasProgress: DKMadsVideoChrome.showsProgress(template: ad.videoTemplate)
        )
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
        ])
        muteButton = button
    }

    private func removeVideoChrome() {
        muteButton?.removeFromSuperview()
        muteButton = nil
    }

    @objc private func muteTapped() {
        isPlaybackMuted.toggle()
        player.isMuted = isPlaybackMuted
        if let muteButton {
            DKMadsVideoChrome.updateMuteButton(muteButton, muted: isPlaybackMuted)
        }
    }

    private func attachVideoClickOverlay(ad: Ad) {
        removeVideoClickOverlay()
        guard !ad.clickUrl.isEmpty else { return }
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(overlay, aboveSubview: playerView)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(videoSurfaceTapped))
        overlay.addGestureRecognizer(tap)
        clickOverlay = overlay
    }

    private func removeVideoClickOverlay() {
        clickOverlay?.removeFromSuperview()
        clickOverlay = nil
    }

    @objc private func videoSurfaceTapped() {
        guard let ad = loadedAd, !ad.clickUrl.isEmpty, let url = URL(string: ad.clickUrl) else { return }
        recordClick()
        rootViewController?.present(SFSafariViewController(url: url), animated: true)
    }

    private func attachClickThroughCta(ad: Ad) {
        ctaButton?.removeFromSuperview()
        let style = DKMadsClickThroughCta.styleForAd(template: ad.videoTemplate, ctaPosition: ad.ctaPosition)
        ctaButton = DKMadsClickThroughCta.attach(
            to: self,
            clickUrl: ad.clickUrl,
            style: style,
            label: ad.ctaLabel,
            presenter: rootViewController,
            onClickThrough: { [weak self] in self?.recordClick() },
        )
    }

    private func stopPlayback() {
        stopViewability()
        cancelSkipTimer()
        removeVideoChrome()
        removeVideoClickOverlay()
        skipButton?.removeFromSuperview()
        skipButton = nil
        ctaButton?.removeFromSuperview()
        ctaButton = nil
        companionImageView?.removeFromSuperview()
        companionImageView = nil
        if videoEventsAttached {
            SSPSDK.shared.stopVideoLifecycleTracking(adUnitId: adUnitID)
            videoEventsAttached = false
        }
        nativePlaybackHandle?.invalidate()
        nativePlaybackHandle = nil
        omidSession?.finish()
        omidSession = nil
        blurBackground?.release()
        blurBackground = nil
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
        // Native video lifecycle already emits `video_viewable` at 50% / 2s.
        // Avoid sending an additional display viewability event for the same video impression.
        if videoEventsAttached { return }
        viewabilityActive = true
        SSPSDK.shared.attachBannerViewability(
            adUnitId: adUnitID,
            containerView: self,
            campaignId: loadedAd?.campaignId,
            creativeId: loadedAd?.creativeId ?? loadedAd?.id,
            minExposureTime: 2.0
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
        webView.evaluateJavaScript(
            DKMadsBannerCreativeLayout.viewportInjectionScript(slotSize: lastVideoRenderSize),
            completionHandler: nil
        )
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
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           let ad = loadedAd,
           ClickThroughNavigation.matches(clickUrl: ad.clickUrl, navigationUrl: url.absoluteString) {
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

    private func effectivePlacementContext(for ad: Ad) -> String? {
        let fromAd = ad.placementContext?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromAd.isEmpty { return fromAd }
        let fromRequest = lastRequestedPlacementContext?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromRequest.isEmpty ? nil : fromRequest
    }

    private func applySkipConfig(from ad: Ad) {
        if let skippable = ad.skippable?.boolValue {
            isSkippable = skippable
        }
        if let sec = ad.skipAfterSec?.doubleValue, sec >= 0 {
            skipOffsetSeconds = sec
        }
    }

    private func emitVideoSkip() {
        guard let ad = loadedAd else { return }
        SSPSDK.shared.trackEvent(
            name: "video_skip",
            data: [
                "ad_unit_id": adUnitID,
                "campaign_id": ad.campaignId as Any,
                "creative_id": (ad.creativeId ?? ad.id),
                "metadata": [
                    "skippable": true,
                ],
            ],
        )
    }

    private func attachCompanion(ad: Ad) {
        companionImageView?.removeFromSuperview()
        guard let urlString = ad.companionImageUrl, !urlString.isEmpty, let url = URL(string: urlString) else { return }
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = ad.showCompanionClick?.boolValue != false && !ad.clickUrl.isEmpty
        if imageView.isUserInteractionEnabled {
            imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(companionTapped)))
        }
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 96),
        ])
        companionImageView = imageView
        URLSession.shared.dataTask(with: url) { [weak imageView] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView?.image = image
            }
        }.resume()
    }

    @objc private func companionTapped() {
        guard let ad = loadedAd, !ad.clickUrl.isEmpty, let url = URL(string: ad.clickUrl) else { return }
        recordClick()
        rootViewController?.present(SFSafariViewController(url: url), animated: true)
    }
}
