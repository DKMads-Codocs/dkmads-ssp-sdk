import Foundation
import WebKit

/// MRAID 2.0 host callbacks. Conformers handle creative-initiated commands.
protocol DKMadsMraidHost: AnyObject {
    func mraidOpen(url: String)
    func mraidClose()
    func mraidExpand(url: String?)
    func mraidUseCustomClose(_ useCustomClose: Bool)
}

extension DKMadsMraidHost {
    func mraidExpand(url: String?) {}
    func mraidUseCustomClose(_ useCustomClose: Bool) {}
}

/// Wires the shared MRAID 2.0 bridge into a `WKWebView`. Inject the script at
/// document start, signal ready/viewable, and forward commands to the host.
final class DKMadsMraidController: NSObject, WKScriptMessageHandler {
    static let messageName = "dkmadsMraid"

    private let placementType: String
    weak var host: DKMadsMraidHost?
    private weak var webView: WKWebView?
    private var ready = false

    init(placementType: String, host: DKMadsMraidHost? = nil) {
        self.placementType = placementType
        self.host = host
        super.init()
    }

    /// Add the MRAID user script + message handler to a configuration before the
    /// web view is created.
    func install(into config: WKWebViewConfiguration) {
        let userScript = WKUserScript(
            source: DKMadsMraidScript.js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(self, name: Self.messageName)
    }

    func bind(webView: WKWebView) {
        self.webView = webView
    }

    func detach() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageName)
    }

    func notifyReady() {
        guard !ready else { return }
        ready = true
        eval("window.mraid && window.mraid._dkmadsSetReady('\(placementType)', \(geometryJson()))")
    }

    func setViewable(_ viewable: Bool) {
        eval("window.mraid && window.mraid._dkmadsSetViewable(\(viewable ? "true" : "false"))")
    }

    func setState(_ state: String) {
        eval("window.mraid && window.mraid._dkmadsSetState('\(state)')")
    }

    private func eval(_ js: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func geometryJson() -> String {
        let screen = UIScreen.main.bounds.size
        let view = webView?.bounds.size ?? screen
        let w = Int(view.width > 0 ? view.width : screen.width)
        let h = Int(view.height > 0 ? view.height : screen.height)
        let sw = Int(screen.width)
        let sh = Int(screen.height)
        return """
        {"currentPosition":{"x":0,"y":0,"width":\(w),"height":\(h)},\
        "defaultPosition":{"x":0,"y":0,"width":\(w),"height":\(h)},\
        "maxSize":{"width":\(sw),"height":\(sh)},\
        "screenSize":{"width":\(sw),"height":\(sh)}}
        """
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName,
              let body = message.body as? [String: Any] else { return }
        let command = (body["command"] as? String) ?? ""
        let payload = (body["payload"] as? [String: Any]) ?? [:]
        DispatchQueue.main.async { [weak self] in
            self?.dispatch(command: command, payload: payload)
        }
    }

    private func dispatch(command: String, payload: [String: Any]) {
        switch command {
        case "open", "playVideo":
            if let url = payload["url"] as? String, !url.isEmpty { host?.mraidOpen(url: url) }
        case "close":
            setState(placementType == "interstitial" ? "hidden" : "default")
            host?.mraidClose()
        case "expand":
            setState("expanded")
            host?.mraidExpand(url: payload["url"] as? String)
        case "useCustomClose":
            host?.mraidUseCustomClose((payload["useCustomClose"] as? Bool) ?? false)
        default:
            break
        }
    }
}
