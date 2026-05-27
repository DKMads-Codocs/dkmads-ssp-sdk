import UIKit

/// Premium video chrome helpers (no native media controller).
enum DKMadsVideoChrome {
    static func showsSkip(template: String?, skippable: Bool) -> Bool {
        if !skippable { return false }
        let t = template?.lowercased() ?? ""
        return t != "video_outstream" && t != "display_video"
    }

    static func showsMute(template: String?) -> Bool { true }

    /// Instream replaces playing content — default sound on; outstream stays muted for autoplay policy.
    static func defaultPlaybackMuted(unitFormat: String?, placementContext: String?, videoTemplate: String?) -> Bool {
        let template = (videoTemplate ?? "").lowercased()
        let format = (unitFormat ?? "").lowercased()
        let ctx = (placementContext ?? "").lowercased()
        if template == "video_instream" || format == "video_instream" || ctx == "instream" { return false }
        return true
    }

    static func showsProgress(template: String?) -> Bool { true }

    static func chromeBottomInset(hasProgress: Bool = true) -> CGFloat {
        hasProgress ? 22 : 12
    }

    static func makeMuteButton(muted: Bool) -> UIButton {
        let button = UIButton(type: .system)
        updateMuteButton(button, muted: muted)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 0.55)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = 32
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size),
        ])
        return button
    }

    static func updateMuteButton(_ button: UIButton, muted: Bool) {
        let name = muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        button.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
        button.accessibilityLabel = muted ? "Unmute advertisement" : "Mute advertisement"
    }
}
