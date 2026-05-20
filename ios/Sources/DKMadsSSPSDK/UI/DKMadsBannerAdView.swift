import Foundation
import UIKit
import WebKit
import SafariServices

@objc public protocol DKMadsBannerAdViewDelegate: AnyObject {
    @objc optional func bannerAdViewDidReceiveAd(_ bannerAdView: DKMadsBannerAdView)
    @objc optional func bannerAdView(_ bannerAdView: DKMadsBannerAdView, didFailToReceiveAdWithError error: Error)
    @objc optional func bannerAdViewDidRecordClick(_ bannerAdView: DKMadsBannerAdView)
    @objc optional func bannerAdViewDidRecordImpression(_ bannerAdView: DKMadsBannerAdView)
    @objc optional func bannerAdViewDidRecordViewableImpression(_ bannerAdView: DKMadsBannerAdView)
}

/// Drop-in banner view with automatic load and IAB viewability tracking.
/// Automatically tracks served impression (on fill) and IAB viewable impression (50%/1s).
@objc public final class DKMadsBannerAdView: UIView {
    @objc public weak var delegate: DKMadsBannerAdViewDelegate?
    @objc public weak var rootViewController: UIViewController?

    @objc public var adUnitID: String
    @objc public var adSize: CGSize
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private let webView: WKWebView
    private let imageView: UIImageView
    private var isLoading = false
    private var viewabilityActive = false

    @objc public init(adUnitID: String, adSize: CGSize = CGSize(width: 300, height: 250)) {
        self.adUnitID = adUnitID
        self.adSize = adSize
        let config = Self.makeWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.imageView = UIImageView(frame: .zero)
        super.init(frame: CGRect(origin: .zero, size: adSize))
        setupViews()
    }

    required init?(coder: NSCoder) {
        self.adUnitID = ""
        self.adSize = CGSize(width: 300, height: 250)
        let config = Self.makeWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.imageView = UIImageView(frame: .zero)
        super.init(coder: coder)
        setupViews()
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil) {
        guard !isLoading else { return }
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.bannerAdView?(self, didFailToReceiveAdWithError: SDKError.notInitialized)
            return
        }
        stopViewability()
        isLoading = true
        clearCreative()

        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .banner,
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
                guard response.success, let ad = response.ad else {
                    let err = DKMadsAdError.noFill.nsError(userInfo: [
                        NSLocalizedDescriptionKey: response.reason ?? "no_fill",
                    ])
                    self.delegate?.bannerAdView?(self, didFailToReceiveAdWithError: err)
                    return
                }
                self.loadedAd = ad
                self.render(ad: ad)
                DispatchQueue.main.async {
                    self.delegate?.bannerAdViewDidReceiveAd?(self)
                    self.delegate?.bannerAdViewDidRecordImpression?(self)
                }
            case .failure(let error):
                self.delegate?.bannerAdView?(self, didFailToReceiveAdWithError: error)
            }
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, loadedAd != nil {
            DispatchQueue.main.async { [weak self] in self?.startViewabilityIfNeeded() }
        } else if window == nil {
            stopViewability()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if loadedAd != nil, window != nil {
            startViewabilityIfNeeded()
        }
    }

    deinit {
        stopViewability()
    }

    private func setupViews() {
        backgroundColor = .clear
        clipsToBounds = true

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
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap)))

        addSubview(webView)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func clearCreative() {
        webView.isHidden = true
        imageView.isHidden = true
        webView.loadHTMLString("", baseURL: nil)
        imageView.image = nil
    }

    private static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.preferences.javaScriptEnabled = true
        return config
    }

    private func render(ad: Ad) {
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
                guard let self, let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.startViewabilityIfNeeded()
                }
            }.resume()
        }
    }

    private func startViewabilityIfNeeded() {
        guard loadedAd != nil, window != nil, !viewabilityActive, bounds.width > 0, bounds.height > 0 else { return }
        viewabilityActive = true
        SSPSDK.shared.attachBannerViewability(
            adUnitId: adUnitID,
            containerView: self,
            creativeId: loadedAd?.id
        ) { [weak self] in
            guard let self else { return }
            self.delegate?.bannerAdViewDidRecordViewableImpression?(self)
        }
    }

    private func stopViewability() {
        if viewabilityActive {
            SSPSDK.shared.detachBannerViewability(adUnitId: adUnitID)
            viewabilityActive = false
        }
    }

    @objc private func onTap() {
        guard let ad = loadedAd else { return }
        SSPSDK.shared.recordAdClick(
            adId: ad.id,
            adUnitId: adUnitID,
            campaignId: ad.campaignId,
            creativeId: ad.creativeId,
            dspSource: ad.dsp
        )
        delegate?.bannerAdViewDidRecordClick?(self)
        guard !ad.clickUrl.isEmpty, let url = URL(string: ad.clickUrl) else { return }
        rootViewController?.present(SFSafariViewController(url: url), animated: true)
    }
}

extension DKMadsBannerAdView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        startViewabilityIfNeeded()
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            let ad = loadedAd
            SSPSDK.shared.recordAdClick(
                adId: ad?.id ?? "",
                adUnitId: adUnitID,
                campaignId: ad?.campaignId,
                creativeId: ad?.creativeId,
                dspSource: ad?.dsp
            )
            delegate?.bannerAdViewDidRecordClick?(self)
            rootViewController?.present(SFSafariViewController(url: url), animated: true)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
