import UIKit
import WebKit
import SafariServices

/// Shared fullscreen presenter for interstitial and app open ads (module-internal).
final class DKMadsInterstitialPresenter: UIViewController {
    let adUnitID: String
    let ad: Ad
    var onDismiss: (() -> Void)?
    var onPlaybackComplete: (() -> Void)?
    var onRenderFailed: ((Error) -> Void)?

    private let contentContainer = UIView()
    private var videoView: DKMadsVideoAdView?
    private let webView: WKWebView
    private let imageView: UIImageView
    private let closeButton: UIButton
    private var viewabilityActive = false
    private var videoConstraints: [NSLayoutConstraint] = []
    private var didPresentStaticContent = false
    private var webContentReady = false

    init(adUnitID: String, ad: Ad) {
        self.adUnitID = adUnitID
        self.ad = ad
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.preferences.javaScriptEnabled = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.imageView = UIImageView()
        self.closeButton = UIButton(type: .custom)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
        setupChrome()
        if ad.isVideo {
            presentVideo()
        } else if !canRenderStatic() {
            failAndDismiss(DKMadsAdError.noFill.nsError(userInfo: [
                NSLocalizedDescriptionKey: "Interstitial creative is not video, image, or HTML5",
            ]))
        }
        bringChromeToFront()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bringChromeToFront()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bringChromeToFront()
        if !ad.isVideo, canRenderStatic(), !didPresentStaticContent, view.bounds.width > 0, view.bounds.height > 0 {
            presentStatic()
        }
        if videoView == nil, canRenderStatic(), !viewabilityActive {
            startViewabilityIfNeeded()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopViewability()
        if isBeingDismissed || presentingViewController == nil {
            onDismiss?()
        }
    }

    private func canRenderStatic() -> Bool {
        ad.isHTML5
            || !(ad.adm?.isEmpty ?? true)
            || !ad.creativeUrl.isEmpty
    }

    private func setupChrome() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
        view.addSubview(contentContainer)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        closeButton.accessibilityLabel = "Close advertisement"
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        } else {
            closeButton.setTitle("✕", for: .normal)
            closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        }
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        webView.isOpaque = false
        webView.backgroundColor = DKMadsCreativeChrome.letterboxBackgroundColor
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(staticTapped)))

        contentContainer.addSubview(webView)
        contentContainer.addSubview(imageView)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            webView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    private func bringChromeToFront() {
        view.bringSubviewToFront(closeButton)
    }

    private func presentVideo() {
        let video = DKMadsVideoAdView(adUnitID: adUnitID)
        video.translatesAutoresizingMaskIntoConstraints = false
        video.rootViewController = self
        video.delegate = self
        video.isSkippable = false
        video.prefersAspectFill = false
        video.wrapsWebMarkupForFullscreen = true
        contentContainer.insertSubview(video, at: 0)
        videoView = video
        NSLayoutConstraint.deactivate(videoConstraints)
        videoConstraints = [
            video.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            video.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            video.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ]
        NSLayoutConstraint.activate(videoConstraints)
        video.display(ad)
        bringChromeToFront()
    }

    private func presentStatic() {
        guard !didPresentStaticContent else { return }
        didPresentStaticContent = true
        webContentReady = false
        let slotSize = view.bounds.size
        if ad.isHTML5 || !(ad.adm?.isEmpty ?? true) {
            webView.isHidden = false
            imageView.isHidden = true
            let base = URL(string: "https://ssp.dkmads.com")
            if let adm = ad.adm, !adm.isEmpty {
                webView.loadHTMLString(
                    DKMadsBannerCreativeLayout.htmlForFullscreen(adm: adm, slotSize: slotSize),
                    baseURL: base
                )
            } else if let entry = ad.html5EntryUrl, let entryURL = URL(string: entry) {
                webView.load(URLRequest(url: entryURL))
            }
            return
        }
        if !ad.creativeUrl.isEmpty, let url = URL(string: ad.creativeUrl) {
            webView.isHidden = true
            imageView.isHidden = false
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let image = UIImage(data: data) else {
                    DispatchQueue.main.async {
                        self?.failAndDismiss(DKMadsAdError.noFill.nsError())
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.startViewabilityIfNeeded()
                    self.bringChromeToFront()
                }
            }.resume()
        }
    }

    private func startViewabilityIfNeeded() {
        guard !viewabilityActive, view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return }
        viewabilityActive = true
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
        SSPSDK.shared.attachBannerViewability(
            adUnitId: adUnitID,
            containerView: contentContainer,
            campaignId: ad.campaignId,
            creativeId: ad.creativeId ?? ad.id
        ) { }
    }

    private func stopViewability() {
        if viewabilityActive {
            SSPSDK.shared.detachBannerViewability(adUnitId: adUnitID)
            viewabilityActive = false
        }
    }

    private func recordClick() {
        SSPSDK.shared.recordAdClick(
            adId: ad.id,
            adUnitId: adUnitID,
            campaignId: ad.campaignId,
            creativeId: ad.creativeId,
            dspSource: ad.dsp
        )
    }

    private func openClickUrl() {
        guard !ad.clickUrl.isEmpty, let url = URL(string: ad.clickUrl) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func staticTapped() {
        recordClick()
        openClickUrl()
    }

    private func failAndDismiss(_ error: Error) {
        onRenderFailed?(error)
        dismiss(animated: true)
    }
}

extension DKMadsInterstitialPresenter: DKMadsVideoAdViewDelegate {
    func videoAdViewDidStartPlayback(_ videoAdView: DKMadsVideoAdView) {
        bringChromeToFront()
    }

    func videoAdViewDidComplete(_ videoAdView: DKMadsVideoAdView) {
        onPlaybackComplete?()
    }

    func videoAdViewDidSkip(_ videoAdView: DKMadsVideoAdView) {
        onPlaybackComplete?()
    }

    func videoAdView(_ videoAdView: DKMadsVideoAdView, didFailToReceiveAdWithError error: Error) {
        failAndDismiss(error)
    }
}

extension DKMadsInterstitialPresenter: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webContentReady = true
        webView.evaluateJavaScript(DKMadsBannerCreativeLayout.fullscreenViewportInjectionScript, completionHandler: nil)
        if let script = DKMadsBannerCreativeLayout.fullscreenClickThroughInjectionScript(clickUrl: ad.clickUrl) {
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        startViewabilityIfNeeded()
        bringChromeToFront()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            decisionHandler(.allow)
            return
        }
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        let isUserClick = navigationAction.navigationType == .linkActivated
            || (webContentReady && navigationAction.navigationType == .other)
        guard isUserClick else {
            decisionHandler(.allow)
            return
        }
        if url.host == "ssp.dkmads.com" {
            decisionHandler(.allow)
            return
        }
        recordClick()
        present(SFSafariViewController(url: url), animated: true)
        decisionHandler(.cancel)
    }
}
