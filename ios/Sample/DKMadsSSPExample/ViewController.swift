import AVFoundation
import UIKit
import DKMadsSSPSDK

/// README Option B — `DKMadsInstreamAdsLoader` (pause content → ad → resume).
final class ViewController: UIViewController, DKMadsInstreamAdsLoaderDelegate {
    private let statusLabel = UILabel()
    private let contentPlayer = AVPlayer()
    private let contentLayer = AVPlayerLayer()
    private let contentContainer = UIView()
    private let adOverlay = UIView()
    private var instreamLoader: DKMadsInstreamAdsLoader?
    private var videoAdUnitID = "YOUR_VIDEO_AD_UNIT_UUID"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Instream (Option B)"

        videoAdUnitID = ProcessInfo.processInfo.environment["DKMADS_VIDEO_AD_UNIT_ID"]
            ?? ProcessInfo.processInfo.environment["DKMADS_AD_UNIT_ID"]
            ?? videoAdUnitID

        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        contentContainer.backgroundColor = .black
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        adOverlay.backgroundColor = .clear
        adOverlay.translatesAutoresizingMaskIntoConstraints = false
        adOverlay.isHidden = true
        contentContainer.addSubview(adOverlay)

        contentLayer.player = contentPlayer
        contentLayer.videoGravity = .resizeAspect
        contentContainer.layer.addSublayer(contentLayer)

        let playContent = UIButton(type: .system)
        playContent.setTitle("Play content + pre-roll", for: .normal)
        playContent.addTarget(self, action: #selector(playContentWithPreroll), for: .touchUpInside)
        playContent.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playContent)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            adOverlay.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            adOverlay.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            adOverlay.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            adOverlay.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            playContent.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 20),
            playContent.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        let loader = DKMadsInstreamAdsLoader(contentPlayer: contentPlayer, adContainer: adOverlay)
        loader.delegate = self
        loader.pauseContentAutomatically = true
        loader.resumeContentAfterAd = true
        instreamLoader = loader

        statusLabel.text = """
        Option B: DKMadsInstreamAdsLoader
        Video ad unit: \(videoAdUnitID)
        Use loader.loadedAd / loader.responseInfo in delegate (single bid).
        """

        if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8") {
            contentPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        contentLayer.frame = contentContainer.bounds
    }

    @objc private func playContentWithPreroll() {
        contentPlayer.play()
        instreamLoader?.requestAds(adUnitID: videoAdUnitID, contentPosition: "pre_roll")
    }

    func instreamAdsLoaderDidStartAd(_ loader: DKMadsInstreamAdsLoader) {
        let summary = loader.responseInfo?.summary ?? "—"
        let dsp = loader.loadedAd?.dsp ?? "—"
        let creative = loader.loadedAd?.creativeId ?? loader.loadedAd?.id ?? "—"
        statusLabel.text = """
        Ad started
        \(summary)
        dsp=\(dsp) creative=\(creative)
        """
    }

    func instreamAdsLoaderDidFinishAd(_ loader: DKMadsInstreamAdsLoader) {
        statusLabel.text = "Pre-roll finished — content resumed.\n\(loader.responseInfo?.summary ?? "")"
    }

    func instreamAdsLoader(_ loader: DKMadsInstreamAdsLoader, didFailWithError error: Error) {
        statusLabel.text = "Pre-roll failed: \(error.localizedDescription)\n\(loader.responseInfo?.summary ?? "")"
    }
}
