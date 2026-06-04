import UIKit

final class DKMadsAdInspectorViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ad Inspector"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Copy ID",
            style: .plain,
            target: self,
            action: #selector(copyRequestId)
        )

        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])

        reloadContent()
    }

    private func reloadContent() {
        if let diag = SSPSDK.shared.lastBidDiagnostics {
            textView.text = diag.detailedText
        } else {
            textView.text = """
            No bid recorded yet.

            1. Enable debug or useTestAds in SSPSDKConfig
            2. Load an ad (banner, interstitial, or app open)
            3. Reopen Ad Inspector

            Tip: Match dashboard ad unit format/size to your creative.
            """
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func copyRequestId() {
        if let id = SSPSDK.shared.lastBidDiagnostics?.requestId {
            UIPasteboard.general.string = id
        }
    }
}
