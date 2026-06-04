import AVFoundation
import UIKit

@objc public protocol DKMadsAudioAdViewDelegate: AnyObject {
    @objc optional func audioAdViewDidReceiveAd(_ view: DKMadsAudioAdView)
    @objc optional func audioAdView(_ view: DKMadsAudioAdView, didFailToReceiveAdWithError error: Error)
    @objc optional func audioAdViewDidStartPlayback(_ view: DKMadsAudioAdView)
    @objc optional func audioAdViewDidCompletePlayback(_ view: DKMadsAudioAdView)
    @objc optional func audioAdViewDidRecordImpression(_ view: DKMadsAudioAdView)
}

/// Loads and plays audio creatives (`audio_url` or audio in `adm`). Emits quartile events via telemetry.
@objc public final class DKMadsAudioAdView: UIView {
    @objc public weak var delegate: DKMadsAudioAdViewDelegate?
    @objc public var adUnitID: String
    @objc public var autoplay: Bool = true
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?

    private var player: AVPlayer?
    private var audioTrackerKey: String?

    @objc public init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.adUnitID = ""
        super.init(coder: coder)
    }

    @objc public func load(_ request: DKMadsAdRequest? = nil) {
        guard SSPSDK.shared.isSDKInitialized else {
            delegate?.audioAdView?(self, didFailToReceiveAdWithError: SDKError.notInitialized)
            return
        }
        stopPlayback()
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .audio,
            sizes: [],
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                guard response.success, let ad = response.ad, ad.isAudio else {
                    let err = DKMadsAdError.noFill.nsError(userInfo: [
                        NSLocalizedDescriptionKey: response.reason ?? "no_fill",
                    ])
                    self.delegate?.audioAdView?(self, didFailToReceiveAdWithError: err)
                    return
                }
                guard let urlString = self.resolveAudioURL(ad: ad), let url = URL(string: urlString) else {
                    self.delegate?.audioAdView?(self, didFailToReceiveAdWithError: SDKError.noFill)
                    return
                }
                self.loadedAd = ad
                SSPSDK.shared.recordAdImpression(
                    adUnitId: self.adUnitID,
                    adId: ad.id,
                    campaignId: ad.campaignId,
                    creativeId: ad.creativeId,
                    dspSource: ad.dsp
                )
                self.delegate?.audioAdViewDidReceiveAd?(self)
                self.delegate?.audioAdViewDidRecordImpression?(self)
                if self.autoplay {
                    self.startPlayback(url: url, ad: ad)
                }
            case .failure(let error):
                self.delegate?.audioAdView?(self, didFailToReceiveAdWithError: error)
            }
        }
    }

    @objc public func play() {
        guard let ad = loadedAd, let urlString = resolveAudioURL(ad: ad), let url = URL(string: urlString) else { return }
        startPlayback(url: url, ad: ad)
    }

    @objc public func stop() {
        stopPlayback()
    }

    private func resolveAudioURL(ad: Ad) -> String? {
        if let url = ad.audioUrl, !url.isEmpty { return url }
        if let adm = ad.adm, let src = AdMediaParsing.firstHtmlAttr(in: adm, name: "src"), !src.isEmpty {
            return src
        }
        return nil
    }

    private func startPlayback(url: URL, ad: Ad) {
        stopPlayback()
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        player = avPlayer
        audioTrackerKey = adUnitID
        SSPSDK.shared.trackAudioLifecycle(
            adUnitId: adUnitID,
            campaignId: ad.campaignId,
            creativeId: ad.creativeId,
            player: avPlayer,
            eventListener: { [weak self] event, _ in
                guard let self else { return }
                if event == "audio_start" {
                    self.delegate?.audioAdViewDidStartPlayback?(self)
                } else if event == "audio_100" {
                    self.delegate?.audioAdViewDidCompletePlayback?(self)
                }
            }
        )
        avPlayer.play()
        delegate?.audioAdViewDidStartPlayback?(self)
    }

    private func stopPlayback() {
        if let key = audioTrackerKey {
            SSPSDK.shared.stopAudioLifecycleTracking(adUnitId: key)
            audioTrackerKey = nil
        }
        player?.pause()
        player = nil
    }

    deinit {
        stopPlayback()
    }
}
