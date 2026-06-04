import UIKit
import DKMadsSSPSDK

/// Mirrors [60-minute quickstart](../../../docs/integration/QUICKSTART.md): init → banner → interstitial → Ad Inspector.
final class ViewController: UIViewController,
    DKMadsBannerAdViewDelegate,
    DKMadsInterstitialAdDelegate {

    private let statusLabel = UILabel()
    private var bannerView: DKMadsBannerAdView?
    private var interstitial: DKMadsInterstitialAd?

    private var integrationKey = "YOUR_INTEGRATION_KEY"
    private var bannerAdUnitID = "YOUR_BANNER_AD_UNIT_UUID"
    private var interstitialAdUnitID = "YOUR_INTERSTITIAL_AD_UNIT_UUID"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "DKMads Quickstart"

        integrationKey = ProcessInfo.processInfo.environment["DKMADS_INTEGRATION_KEY"] ?? integrationKey
        bannerAdUnitID = ProcessInfo.processInfo.environment["DKMADS_BANNER_AD_UNIT_ID"] ?? bannerAdUnitID
        interstitialAdUnitID = ProcessInfo.processInfo.environment["DKMADS_INTERSTITIAL_AD_UNIT_ID"]
            ?? ProcessInfo.processInfo.environment["DKMADS_AD_UNIT_ID"]
            ?? interstitialAdUnitID

        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        stack.addArrangedSubview(makeButton("1. Initialize SDK", action: #selector(initializeSDK)))
        stack.addArrangedSubview(makeButton("2. Load banner", action: #selector(loadBanner)))
        stack.addArrangedSubview(makeButton("3. Load & show interstitial", action: #selector(loadAndShowInterstitial)))
        stack.addArrangedSubview(makeButton("Ad Inspector", action: #selector(openInspector)))

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        log("Set DKMADS_INTEGRATION_KEY, DKMADS_BANNER_AD_UNIT_ID, DKMADS_INTERSTITIAL_AD_UNIT_ID in the scheme.")
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.addTarget(self, action: action, for: .touchUpInside)
        b.contentHorizontalAlignment = .leading
        return b
    }

    private func log(_ text: String) {
        statusLabel.text = text
    }

    @objc private func initializeSDK() {
        let cfg = SSPSDKConfig(integrationKey: integrationKey)
        cfg.baseURL = "https://ssp.dkmads.com"
        cfg.debug = true
        DKMadsMobileAds.shared.start(with: cfg)
        log("SDK started (debug on).")
    }

    @objc private func loadBanner() {
        bannerView?.removeFromSuperview()
        let banner = DKMadsBannerAdView(
            adUnitID: bannerAdUnitID,
            adSize: CGSize(width: 300, height: 250)
        )
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.centerYAnchor),
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.widthAnchor.constraint(equalToConstant: 300),
            banner.heightAnchor.constraint(equalToConstant: 250),
        ])
        bannerView = banner
        banner.load()
        log("Loading banner \(bannerAdUnitID)…")
    }

    @objc private func loadAndShowInterstitial() {
        log("Loading interstitial…")
        DKMadsInterstitialAd.load(adUnitID: interstitialAdUnitID) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                self.log("Interstitial failed: \(error.localizedDescription)")
                return
            }
            guard let ad else {
                self.log("Interstitial no fill.")
                return
            }
            self.interstitial = ad
            ad.delegate = self
            ad.present(from: self)
        }
    }

    @objc private func openInspector() {
        DKMadsMobileAds.shared.presentAdInspector(from: self)
    }

    func bannerAdViewDidReceiveAd(_ bannerAdView: DKMadsBannerAdView) {
        log("Banner loaded.\n\(bannerAdView.responseInfo?.summary ?? "")")
    }

    func bannerAdView(_ bannerAdView: DKMadsBannerAdView, didFailToReceiveAdWithError error: Error) {
        log("Banner failed: \(error.localizedDescription)")
    }

    func interstitialAdDidReceiveAd(_ ad: DKMadsInterstitialAd) {
        log("Interstitial ready.")
    }

    func interstitialAdDidDismiss(_ ad: DKMadsInterstitialAd) {
        log("Interstitial dismissed.\n\(SSPSDK.shared.lastBidDiagnostics?.summaryText ?? "")")
    }

    func interstitialAd(_ ad: DKMadsInterstitialAd, didFailToReceiveAdWithError error: Error) {
        log("Interstitial error: \(error.localizedDescription)")
    }
}
