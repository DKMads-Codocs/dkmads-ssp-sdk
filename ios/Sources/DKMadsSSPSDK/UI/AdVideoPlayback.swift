import AVFoundation
import Foundation
import WebKit

enum AdVideoPlayback {
    static let baseURL = URL(string: "https://ssp.dkmads.com")

    static func makeWebViewConfiguration(bridge: AdVideoWebPlaybackBridge) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.preferences.javaScriptEnabled = true
        let controller = config.userContentController
        controller.add(bridge, name: AdVideoWebEvents.messageChannel)
        let script = WKUserScript(
            source: AdVideoWebEvents.endDetectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)
        return config
    }

    static func injectVideoEndDetection(in webView: WKWebView) {
        webView.evaluateJavaScript(AdVideoWebEvents.endDetectionScript, completionHandler: nil)
    }

    static func isAdCompleteNavigation(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme?.lowercased() == AdVideoWebEvents.completeScheme
            && url.host?.lowercased() == AdVideoWebEvents.completeHost
    }

    static func loadWebMarkup(ad: Ad, in webView: WKWebView, autoplay: Bool) {
        let html: String
        if let adm = ad.adm, !adm.isEmpty {
            html = adm
        } else if let url = ad.preferredPlaybackURL, let entry = URL(string: url) {
            webView.load(URLRequest(url: entry))
            return
        } else {
            return
        }
        if autoplay, !html.lowercased().contains("autoplay") {
            let injected = html.replacingOccurrences(
                of: "<video",
                with: "<video playsinline webkit-playsinline autoplay muted",
                options: .caseInsensitive
            )
            webView.loadHTMLString(injected, baseURL: baseURL)
        } else {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    static func loadNative(
        ad: Ad,
        player: AVPlayer,
        autoplay: Bool,
        onReady: @escaping (Error?) -> Void
    ) {
        guard let urlString = ad.preferredPlaybackURL, let url = URL(string: urlString) else {
            onReady(DKMadsAdError.missingVideoURL.nsError())
            return
        }
        let item = AVPlayerItem(url: url)
        var observer: NSKeyValueObservation?
        observer = item.observe(\.status, options: [.initial, .new]) { observed, _ in
            switch observed.status {
            case .readyToPlay:
                observer?.invalidate()
                if autoplay { player.play() }
                onReady(nil)
            case .failed:
                observer?.invalidate()
                onReady(DKMadsAdError.playbackFailed.nsError(userInfo: [
                    NSUnderlyingErrorKey: observed.error as Any,
                ]))
            default:
                break
            }
        }
        player.replaceCurrentItem(with: item)
    }
}
