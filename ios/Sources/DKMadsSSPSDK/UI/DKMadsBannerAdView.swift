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
    @objc public var adSize: CGSize {
        didSet {
            guard adSize.width > 0, adSize.height > 0 else { return }
            invalidateIntrinsicContentSize()
        }
    }
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private let webView: WKWebView
    private let imageView: UIImageView
    private var isLoading = false
    private var loadGeneration: UInt = 0
    private var lastBannerSlotSize: CGSize = CGSize(width: 300, height: 250)
    private var viewabilityActive = false
    private var refreshTimer: Timer?
    private var lastAdRequest: DKMadsAdRequest?

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

    /// Updates IAB bid metadata (`adSize`) — does not resize the view; use Auto Layout constraints for layout.
    @objc(updateAdSize:)
    public func updateAdSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        adSize = size
    }

    public override var intrinsicContentSize: CGSize {
        adSize.width > 0 && adSize.height > 0 ? adSize : CGSize(width: 300, height: 250)
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil, bidSize: CGSize = .zero) {
        guard !isLoading else { return }
        let effectiveRequest = Self.normalizedRequest(request ?? lastAdRequest, adUnitID: adUnitID)
        lastAdRequest = effectiveRequest
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.bannerAdView?(self, didFailToReceiveAdWithError: SDKError.notInitialized)
            return
        }
        stopViewability()
        let generation = loadGeneration &+ 1
        loadGeneration = generation
        isLoading = true
        clearCreative()

        let bidSizeForRequest = (bidSize.width > 0 && bidSize.height > 0)
            ? bidSize
            : DKMadsBannerCreativeLayout.bidSlotSize(adSize: adSize)

        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .banner,
            sizes: [bidSizeForRequest],
            placementCode: effectiveRequest.placementCode,
            placementContext: effectiveRequest.placementContext,
            keyValues: effectiveRequest.keyValues
        ) { [weak self] result in
            guard let self else { return }
            guard generation == self.loadGeneration else { return }
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
                SSPSDK.shared.recordAdImpression(
                    adUnitId: self.adUnitID,
                    adId: ad.id,
                    campaignId: ad.campaignId,
                    creativeId: ad.creativeId,
                    dspSource: ad.dsp
                )
                ad.impressionRecorded = true
                DispatchQueue.main.async {
                    self.delegate?.bannerAdViewDidReceiveAd?(self)
                    self.delegate?.bannerAdViewDidRecordImpression?(self)
                    self.scheduleRefreshIfNeeded(response.refreshIntervalSec?.intValue)
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
        refreshTimer?.invalidate()
        stopViewability()
    }

    /// Fills `placementCode` / `placementContext` when omitted (server rejects explicit null).
    private static func normalizedRequest(_ request: DKMadsAdRequest?, adUnitID: String) -> DKMadsAdRequest {
        let req = request ?? DKMadsAdRequest()
        if (req.placementCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.placementCode = adUnitID
        }
        if (req.placementContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.placementContext = "banner"
        }
        return req
    }

    private func scheduleRefreshIfNeeded(_ intervalSec: Int?) {
        refreshTimer?.invalidate()
        guard let sec = intervalSec, sec >= 30 else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(sec), repeats: true) { [weak self] _ in
            self?.load(self?.lastAdRequest)
        }
    }

    private func setupViews() {
        backgroundColor = .clear
        clipsToBounds = true

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
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

    static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.preferences.javaScriptEnabled = true
        return config
    }

    private func render(ad: Ad) {
        let renderSlot = DKMadsBannerCreativeLayout.renderSlotSize(adSize: adSize, bounds: bounds.size)
        lastBannerSlotSize = renderSlot
        if ad.isHTML5 || !(ad.adm?.isEmpty ?? true) {
            webView.isHidden = false
            imageView.isHidden = true
            let base = URL(string: "https://ssp.dkmads.com")
            if let adm = ad.adm, !adm.isEmpty {
                webView.loadHTMLString(DKMadsBannerCreativeLayout.htmlForBanner(adm: adm, slotSize: renderSlot), baseURL: base)
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
            campaignId: loadedAd?.campaignId,
            creativeId: loadedAd?.creativeId ?? loadedAd?.id
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
        webView.evaluateJavaScript(
            DKMadsBannerCreativeLayout.viewportInjectionScript(slotSize: lastBannerSlotSize),
            completionHandler: nil
        )
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
