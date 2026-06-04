import AVFoundation
import Foundation
import WebKit

enum AdVideoPlayback {
    static let initialLoadTimeout: TimeInterval = 15
    static let bufferStallTimeout: TimeInterval = 12
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
        onReady: @escaping (Error?) -> Void,
        onBuffering: ((Bool) -> Void)? = nil,
        onStallFailed: ((Error) -> Void)? = nil
    ) -> AdNativePlaybackHandle? {
        guard let urlString = ad.preferredPlaybackURL, let url = URL(string: urlString) else {
            onReady(DKMadsAdError.missingVideoURL.nsError())
            return nil
        }
        let item = AVPlayerItem(url: url)
        let handle = AdNativePlaybackHandle(
            item: item,
            player: player,
            autoplay: autoplay,
            onReady: onReady,
            onBuffering: onBuffering,
            onStallFailed: onStallFailed
        )
        player.replaceCurrentItem(with: item)
        return handle
    }
}

final class AdNativePlaybackHandle {
    private let item: AVPlayerItem
    private let player: AVPlayer
    private let autoplay: Bool
    private let onReady: (Error?) -> Void
    private let onBuffering: ((Bool) -> Void)?
    private let onStallFailed: ((Error) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var loadTimeoutWork: DispatchWorkItem?
    private var bufferTimeoutWork: DispatchWorkItem?
    private var didFinishReady = false
    private var isBuffering = false

    init(
        item: AVPlayerItem,
        player: AVPlayer,
        autoplay: Bool,
        onReady: @escaping (Error?) -> Void,
        onBuffering: ((Bool) -> Void)?,
        onStallFailed: ((Error) -> Void)?
    ) {
        self.item = item
        self.player = player
        self.autoplay = autoplay
        self.onReady = onReady
        self.onBuffering = onBuffering
        self.onStallFailed = onStallFailed
        attachObservers()
        scheduleLoadTimeout()
    }

    func invalidate() {
        loadTimeoutWork?.cancel()
        bufferTimeoutWork?.cancel()
        observations.forEach { $0.invalidate() }
        observations.removeAll()
    }

    deinit {
        invalidate()
    }

    private func attachObservers() {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            self?.handleStatus(observed.status, error: observed.error)
        })
        observations.append(item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] observed, _ in
            if observed.isPlaybackBufferEmpty {
                self?.enterBuffering()
            }
        })
        observations.append(item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] observed, _ in
            if observed.isPlaybackLikelyToKeepUp {
                self?.leaveBuffering()
            }
        })
    }

    private func handleStatus(_ status: AVPlayerItem.Status, error: Error?) {
        switch status {
        case .readyToPlay:
            guard !didFinishReady else { return }
            didFinishReady = true
            loadTimeoutWork?.cancel()
            if autoplay { player.play() }
            onReady(nil)
        case .failed:
            guard !didFinishReady else { return }
            didFinishReady = true
            loadTimeoutWork?.cancel()
            onReady(DKMadsAdError.playbackFailed.nsError(userInfo: [
                NSUnderlyingErrorKey: error as Any,
            ]))
        default:
            break
        }
    }

    private func scheduleLoadTimeout() {
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.didFinishReady else { return }
            self.didFinishReady = true
            let error = DKMadsAdError.playbackFailed.nsError(userInfo: [
                NSLocalizedDescriptionKey: "Video playback timed out while loading.",
            ])
            self.onReady(error)
            self.onStallFailed?(error)
        }
        loadTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AdVideoPlayback.initialLoadTimeout, execute: work)
    }

    private func enterBuffering() {
        guard didFinishReady else { return }
        onBuffering?(true)
        isBuffering = true
        bufferTimeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isBuffering, self.item.isPlaybackBufferEmpty else { return }
            let error = DKMadsAdError.playbackFailed.nsError(userInfo: [
                NSLocalizedDescriptionKey: "Video playback stalled while buffering.",
            ])
            self.onStallFailed?(error)
        }
        bufferTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AdVideoPlayback.bufferStallTimeout, execute: work)
    }

    private func leaveBuffering() {
        guard isBuffering else { return }
        isBuffering = false
        bufferTimeoutWork?.cancel()
        onBuffering?(false)
    }
}
