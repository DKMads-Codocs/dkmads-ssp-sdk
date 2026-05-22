import SafariServices
import UIKit

enum DKMadsClickThroughCta {
    @discardableResult
    static func attach(
        to parent: UIView,
        clickUrl: String?,
        presenter: UIViewController?,
        onClickThrough: @escaping () -> Void
    ) -> UIButton? {
        let urlString = clickUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }

        let button = UIButton(type: .system)
        button.setTitle("Learn more", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.1, green: 0.45, blue: 0.91, alpha: 1)
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.accessibilityLabel = "Advertisement — learn more"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { _ in
            onClickThrough()
            guard let presenter else { return }
            presenter.present(SFSafariViewController(url: url), animated: true)
        }, for: .touchUpInside)

        parent.addSubview(button)
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            button.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
        ])
        return button
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
