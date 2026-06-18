import Foundation
import UIKit
import WebKit
import SafariServices

@objc public protocol DKMadsNativeAdViewDelegate: AnyObject {
    @objc optional func nativeAdViewDidReceiveAd(_ nativeAdView: DKMadsNativeAdView)
    @objc optional func nativeAdView(_ nativeAdView: DKMadsNativeAdView, didFailToReceiveAdWithError error: Error)
    @objc optional func nativeAdViewDidRecordClick(_ nativeAdView: DKMadsNativeAdView)
    @objc optional func nativeAdViewDidRecordImpression(_ nativeAdView: DKMadsNativeAdView)
    @objc optional func nativeAdViewDidRecordViewableImpression(_ nativeAdView: DKMadsNativeAdView)
}

/// Native-format ad view (image / HTML adm). Same lifecycle as banner with format `native`.
@objc public final class DKMadsNativeAdView: UIView {
    @objc public weak var delegate: DKMadsNativeAdViewDelegate?
    @objc public weak var rootViewController: UIViewController?
    @objc public var adUnitID: String
    @objc public var adSize: CGSize
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private let webView: WKWebView
    private let imageView: UIImageView
    private let mraid: DKMadsMraidController
    private var mraidActive = false
    private var omidSession: DKMadsOmidSession?
    private var isLoading = false
    private var viewabilityActive = false

    @objc public init(adUnitID: String, adSize: CGSize = CGSize(width: 300, height: 250)) {
        self.adUnitID = adUnitID
        self.adSize = adSize
        let config = DKMadsBannerAdView.makeWebViewConfiguration()
        let mraid = DKMadsMraidController(placementType: "inline")
        mraid.install(into: config)
        self.mraid = mraid
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.imageView = UIImageView(frame: .zero)
        super.init(frame: CGRect(origin: .zero, size: adSize))
        mraid.host = self
        mraid.bind(webView: webView)
        setupViews()
    }

    required init?(coder: NSCoder) {
        self.adUnitID = ""
        self.adSize = CGSize(width: 300, height: 250)
        let config = DKMadsBannerAdView.makeWebViewConfiguration()
        let mraid = DKMadsMraidController(placementType: "inline")
        mraid.install(into: config)
        self.mraid = mraid
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.imageView = UIImageView(frame: .zero)
        super.init(coder: coder)
        mraid.host = self
        mraid.bind(webView: webView)
        setupViews()
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil) {
        guard !isLoading else { return }
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.nativeAdView?(self, didFailToReceiveAdWithError: SDKError.notInitialized)
            return
        }
        stopViewability()
        isLoading = true
        clearCreative()
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .native,
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
                    self.delegate?.nativeAdView?(self, didFailToReceiveAdWithError: err)
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
                    self.delegate?.nativeAdViewDidReceiveAd?(self)
                    self.delegate?.nativeAdViewDidRecordImpression?(self)
                }
            case .failure(let error):
                self.delegate?.nativeAdView?(self, didFailToReceiveAdWithError: error)
            }
        }
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
        omidSession?.finish()
        omidSession = nil
        webView.isHidden = true
        imageView.isHidden = true
        webView.loadHTMLString("", baseURL: nil)
        imageView.image = nil
    }

    private func startOmidNativeSession() {
        guard omidSession == nil, DKMadsOmid.isAvailable, let ad = loadedAd else { return }
        omidSession = DKMadsOmid.provider?.createNativeDisplaySession(adView: self, verifications: ad.omidVerifications)
        omidSession?.start()
        omidSession?.signalLoaded()
    }

    private func render(ad: Ad) {
        let html5Entry = DKMadsBannerCreativeLayout.resolveHtml5EntryUrl(ad: ad)
        let preferImage = ad.renderModeHint == "image" && !ad.creativeUrl.isEmpty
        if !preferImage, html5Entry != nil || ad.isHTML5 || !(ad.adm?.isEmpty ?? true) {
            mraidActive = ad.isMraidCreative
            webView.isHidden = false
            imageView.isHidden = true
            let base = URL(string: "https://ssp.dkmads.com")
            if let entry = html5Entry, let entryURL = URL(string: entry) {
                webView.load(URLRequest(url: entryURL))
            } else if let adm = ad.adm, !adm.isEmpty {
                webView.loadHTMLString(adm, baseURL: base)
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
                    self.startOmidNativeSession()
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
            if self.mraidActive { self.mraid.setViewable(true) }
            self.omidSession?.signalImpression()
            self.delegate?.nativeAdViewDidRecordViewableImpression?(self)
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
        delegate?.nativeAdViewDidRecordClick?(self)
        guard !ad.clickUrl.isEmpty, let url = URL(string: ad.clickUrl) else { return }
        rootViewController?.present(SFSafariViewController(url: url), animated: true)
    }
}

extension DKMadsNativeAdView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if mraidActive { mraid.notifyReady() }
        if omidSession == nil, DKMadsOmid.isAvailable {
            omidSession = DKMadsOmid.provider?.createHtmlDisplaySession(webView: webView)
            omidSession?.start()
            omidSession?.signalLoaded()
        }
        startViewabilityIfNeeded()
    }
}

extension DKMadsNativeAdView: DKMadsMraidHost {
    func mraidOpen(url: String) {
        guard let target = URL(string: url) else { return }
        if let ad = loadedAd {
            SSPSDK.shared.recordAdClick(
                adId: ad.id,
                adUnitId: adUnitID,
                campaignId: ad.campaignId,
                creativeId: ad.creativeId,
                dspSource: ad.dsp
            )
        }
        delegate?.nativeAdViewDidRecordClick?(self)
        rootViewController?.present(SFSafariViewController(url: target), animated: true)
    }

    func mraidClose() {
        mraid.setViewable(false)
    }
}
