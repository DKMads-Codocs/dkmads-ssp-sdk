import SafariServices
import UIKit

enum VideoCtaStyle {
    case `default`
    case outstreamBar
    case rewarded
    case endCard
    case barBelow
}

enum DKMadsClickThroughCta {
    @discardableResult
    static func attach(
        to parent: UIView,
        clickUrl: String?,
        style: VideoCtaStyle = .default,
        label: String = "Learn more",
        presenter: UIViewController?,
        onClickThrough: @escaping () -> Void
    ) -> UIButton? {
        let urlString = clickUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }

        let button = ClickThroughButton(type: .system)
        let title = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Learn more" : label
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.1, green: 0.45, blue: 0.91, alpha: 1)
        button.layer.cornerRadius = style == .rewarded ? 8 : 6
        button.accessibilityLabel = "Advertisement — learn more"
        button.translatesAutoresizingMaskIntoConstraints = false
        switch style {
        case .rewarded:
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        case .outstreamBar:
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.layer.cornerRadius = 0
        case .default, .endCard:
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        case .barBelow:
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.layer.cornerRadius = 0
        }
        if style == .endCard {
            button.backgroundColor = UIColor(red: 0.1, green: 0.45, blue: 0.91, alpha: 0.92)
        }
        button.configureClickThrough(url: url, presenter: presenter, onClickThrough: onClickThrough)

        parent.addSubview(button)
        switch style {
        case .outstreamBar:
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])
        case .rewarded:
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(greaterThanOrEqualTo: parent.leadingAnchor, constant: 16),
                button.trailingAnchor.constraint(lessThanOrEqualTo: parent.trailingAnchor, constant: -16),
                button.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
                button.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                button.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            ])
        case .endCard:
            NSLayoutConstraint.activate([
                button.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -10),
                button.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            ])
        case .barBelow:
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            ])
        case .default:
            NSLayoutConstraint.activate([
                button.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -12),
                button.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            ])
        }
        return button
    }

    static func styleForTemplate(_ template: String?) -> VideoCtaStyle {
        switch template?.lowercased() {
        case "video_outstream": return .outstreamBar
        case "rewarded", "splash": return .rewarded
        default: return .default
        }
    }

    static func styleForAd(template: String?, ctaPosition: String?) -> VideoCtaStyle {
        switch ctaPosition?.lowercased() {
        case "end_card": return .endCard
        case "bar_below":
            if template?.lowercased() == "video_outstream" { return .outstreamBar }
            return .barBelow
        default: return styleForTemplate(template)
        }
    }
}

private final class ClickThroughButton: UIButton {
    private var onTap: (() -> Void)?

    func configureClickThrough(
        url: URL,
        presenter: UIViewController?,
        onClickThrough: @escaping () -> Void
    ) {
        onTap = {
            onClickThrough()
            guard let presenter else { return }
            presenter.present(SFSafariViewController(url: url), animated: true)
        }
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    @objc private func tapped() {
        onTap?()
    }
}

enum ClickThroughNavigation {
    static func matches(clickUrl: String?, navigationUrl: String?) -> Bool {
        let click = clickUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nav = navigationUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !click.isEmpty, !nav.isEmpty else { return false }
        if nav == click { return true }
        return nav.hasPrefix(click)
    }
}
