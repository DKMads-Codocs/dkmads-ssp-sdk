import Foundation
import UIKit
import WebKit
import SafariServices

@objc public protocol DKMadsInterstitialAdDelegate: AnyObject {
    @objc optional func interstitialAdDidReceiveAd(_ ad: DKMadsInterstitialAd)
    @objc optional func interstitialAd(_ ad: DKMadsInterstitialAd, didFailToReceiveAdWithError error: Error)
    @objc optional func interstitialAdDidPresent(_ ad: DKMadsInterstitialAd)
    @objc optional func interstitialAdDidDismiss(_ ad: DKMadsInterstitialAd)
}

/// Fullscreen interstitial (video, image, HTML5, or tag). Use for dashboard format `interstitial`.
@objc(DKMadsInterstitialAd)
public final class DKMadsInterstitialAd: NSObject {
    @objc public weak var delegate: DKMadsInterstitialAdDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private var presenter: DKMadsInterstitialPresenter?

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

    public func load(
        adSize: CGSize? = nil,
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsInterstitialAd?, Error?) -> Void
    ) {
        guard SSPSDK.shared.isSDKInitialized else {
            completion(nil, DKMadsAdError.notInitialized.nsError())
            return
        }
        let bidSizes = Self.bidSizes(adUnitID: adUnitID, adSize: adSize)
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .interstitial,
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
                    self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: err)
                    completion(nil, err)
                    return
                }
                self.loadedAd = ad
                self.delegate?.interstitialAdDidReceiveAd?(self)
                completion(self, nil)
            case .failure(let error):
                self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: error)
                completion(nil, error)
            }
        }
    }

    /// IAB interstitial tokens for bid matching — not raw UIScreen pixel dimensions.
    private static func bidSizes(adUnitID: String, adSize: CGSize?) -> [CGSize] {
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
        let vc = DKMadsInterstitialPresenter(adUnitID: adUnitID, ad: loadedAd)
        vc.onDismiss = { [weak self] in
            guard let self else { return }
            self.presenter = nil
            self.delegate?.interstitialAdDidDismiss?(self)
        }
        vc.onPlaybackComplete = { [weak self] in
            self?.presenter?.dismiss(animated: true)
        }
        vc.onRenderFailed = { [weak self] error in
            guard let self else { return }
            self.presenter = nil
            rootViewController.dismiss(animated: true)
            self.delegate?.interstitialAd?(self, didFailToReceiveAdWithError: error)
        }
        presenter = vc
        rootViewController.present(vc, animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.interstitialAdDidPresent?(self)
        }
    }
}

private final class DKMadsInterstitialPresenter: UIViewController {
    let adUnitID: String
    let ad: Ad
    var onDismiss: (() -> Void)?
    var onPlaybackComplete: (() -> Void)?
    var onRenderFailed: ((Error) -> Void)?

    private var videoView: DKMadsVideoAdView?
    private let webView: WKWebView
    private let imageView: UIImageView
    private let closeButton: UIButton
    private var viewabilityActive = false

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
        self.closeButton = UIButton(type: .system)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupChrome()
        if ad.isVideo {
            presentVideo()
        } else if canRenderStatic() {
            presentStatic()
        } else {
            failAndDismiss(DKMadsAdError.noFill.nsError(userInfo: [
                NSLocalizedDescriptionKey: "Interstitial creative is not video, image, or HTML5",
            ]))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopViewability()
        if isBeingDismissed || presentingViewController == nil {
            onDismiss?()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if videoView == nil, canRenderStatic(), !viewabilityActive {
            startViewabilityIfNeeded()
        }
    }

    private func canRenderStatic() -> Bool {
        ad.isHTML5
            || !(ad.adm?.isEmpty ?? true)
            || !ad.creativeUrl.isEmpty
    }

    private func setupChrome() {
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        closeButton.layer.cornerRadius = 18
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(staticTapped)))

        view.addSubview(webView)
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func presentVideo() {
        let video = DKMadsVideoAdView(adUnitID: adUnitID, frame: view.bounds)
        video.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        video.rootViewController = self
        video.delegate = self
        video.isSkippable = true
        view.insertSubview(video, at: 0)
        videoView = video
        video.display(ad)
    }

    private func presentStatic() {
        if ad.isHTML5 || !(ad.adm?.isEmpty ?? true) {
            webView.isHidden = false
            imageView.isHidden = true
            let base = URL(string: "https://ssp.dkmads.com")
            if let adm = ad.adm, !adm.isEmpty {
                webView.loadHTMLString(adm, baseURL: base)
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
                }
            }.resume()
        }
    }

    private func startViewabilityIfNeeded() {
        guard !viewabilityActive, view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return }
        viewabilityActive = true
        SSPSDK.shared.attachBannerViewability(
            adUnitId: adUnitID,
            containerView: view,
            creativeId: ad.id
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
        startViewabilityIfNeeded()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            recordClick()
            present(SFSafariViewController(url: url), animated: true)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
