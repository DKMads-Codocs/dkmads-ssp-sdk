import Foundation
import WebKit

enum AdVideoWebEvents {
    static let messageChannel = "dkmadsVideo"
    static let completeScheme = "ssp-dkmads"
    static let completeHost = "ad-complete"

    /// Hooks HTML5 `<video>` ended → WKScriptMessage or custom-scheme fallback.
    static let endDetectionScript = """
    (function() {
      function notifyComplete() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(messageChannel)) {
          window.webkit.messageHandlers.\(messageChannel).postMessage('complete');
        } else {
          window.location = '\(completeScheme)://\(completeHost)';
        }
      }
      function hook(v) {
        if (!v || v.__dkmadsEndHooked) return;
        v.__dkmadsEndHooked = true;
        v.addEventListener('ended', notifyComplete);
      }
      document.querySelectorAll('video').forEach(hook);
      if (document.body) {
        new MutationObserver(function() {
          document.querySelectorAll('video').forEach(hook);
        }).observe(document.body, { childList: true, subtree: true });
      }
    })();
    """
}

final class AdVideoWebPlaybackBridge: NSObject, WKScriptMessageHandler {
    var onComplete: (() -> Void)?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == AdVideoWebEvents.messageChannel else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onComplete?()
        }
    }
}
