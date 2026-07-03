import AVFoundation
import UIKit

/// Blurred video backdrop for `contain_blur` — synced duplicate player behind the main creative.
final class DKMadsVideoBlurBackground {
    private let container = UIView()
    private let blurPlayerHost = UIView()
    private let blurEffectView: UIVisualEffectView
    private var blurPlayer: AVPlayer?
    private var blurLayer: AVPlayerLayer?
    private var timeObserver: Any?
    private weak var mainPlayer: AVPlayer?

    init() {
        blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blurEffectView.alpha = 0.9
    }

    func attach(in parent: UIView, below sibling: UIView) {
        if container.superview !== parent {
            container.translatesAutoresizingMaskIntoConstraints = false
            container.clipsToBounds = true
            parent.insertSubview(container, belowSubview: sibling)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: parent.topAnchor),
                container.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
                container.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            ])

            blurPlayerHost.translatesAutoresizingMaskIntoConstraints = false
            blurPlayerHost.clipsToBounds = true
            container.addSubview(blurPlayerHost)
            NSLayoutConstraint.activate([
                blurPlayerHost.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                blurPlayerHost.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                blurPlayerHost.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 1.4),
                blurPlayerHost.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 1.4),
            ])

            blurEffectView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(blurEffectView)
            NSLayoutConstraint.activate([
                blurEffectView.topAnchor.constraint(equalTo: container.topAnchor),
                blurEffectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                blurEffectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                blurEffectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }
        container.isHidden = false
    }

    func bind(mainPlayer: AVPlayer) {
        releasePlayersOnly()
        self.mainPlayer = mainPlayer
        guard let item = mainPlayer.currentItem else { return }
        let asset = item.asset
        let blurItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: blurItem)
        player.isMuted = true
        blurPlayer = player
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.clear.cgColor
        blurPlayerHost.layer.addSublayer(layer)
        blurLayer = layer
        layoutBlurLayer()

        timeObserver = mainPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak player] time in
            guard let self, let player else { return }
            let delta = abs(player.currentTime().seconds - time.seconds)
            if delta > 0.35 {
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            if self.mainPlayer?.rate ?? 0 > 0, player.rate == 0 {
                player.play()
            } else if self.mainPlayer?.rate ?? 0 == 0, player.rate > 0 {
                player.pause()
            }
        }
        if mainPlayer.rate > 0 {
            player.play()
        }
    }

    func layoutBlurLayer() {
        blurLayer?.frame = blurPlayerHost.bounds
    }

    func release() {
        releasePlayersOnly()
        container.removeFromSuperview()
    }

    private func releasePlayersOnly() {
        if let timeObserver, let mainPlayer {
            mainPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        mainPlayer = nil
        blurPlayer?.pause()
        blurPlayer?.replaceCurrentItem(with: nil)
        blurPlayer = nil
        blurLayer?.removeFromSuperlayer()
        blurLayer = nil
    }
}
