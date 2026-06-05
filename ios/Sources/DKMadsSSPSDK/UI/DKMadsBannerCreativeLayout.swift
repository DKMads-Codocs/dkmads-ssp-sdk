import CoreGraphics
import Foundation

enum DKMadsBannerCreativeLayout {
    static func effectiveSlotSize(adSize: CGSize, bounds: CGSize) -> CGSize {
        if bounds.width > 0, bounds.height > 0 { return bounds }
        if adSize.width > 0, adSize.height > 0 { return adSize }
        return CGSize(width: 300, height: 250)
    }

    static func htmlForBanner(adm: String, slotSize: CGSize) -> String {
        if adm.lowercased().contains("<html") { return adm }
        return htmlForSlot(adm: adm, slotSize: slotSize, objectFit: "contain", fullscreen: false)
    }

    /// Fullscreen interstitial / app open — always re-wrap (even full HTML documents) and letterbox to fit the device.
    static func htmlForFullscreen(adm: String, slotSize: CGSize) -> String {
        let fragment = extractRenderableFragment(from: adm)
        return htmlForSlot(adm: fragment, slotSize: slotSize, objectFit: "contain", fullscreen: true)
    }

    private static func extractRenderableFragment(from adm: String) -> String {
        let trimmed = adm.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.contains("<html") || lower.contains("<!doctype") else { return trimmed }
        if let body = firstCapture(in: trimmed, pattern: "(?is)<body[^>]*>(.*)</body>") {
            return body.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capture])
    }

    private static func htmlForSlot(adm: String, slotSize: CGSize, objectFit: String, fullscreen: Bool) -> String {
        let w = max(1, Int(slotSize.width.rounded()))
        let h = max(1, Int(slotSize.height.rounded()))
        let viewport = fullscreen
            ? "width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
            : "width=\(w), height=\(h), initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
        let rootStyle = "#dkmads-root{width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box;background:\(fullscreen ? "#000" : "transparent")}"
        let mediaStyle = fullscreen
            ? "display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:\(objectFit);border:0;margin:0;padding:0"
            : "display:block;width:100%;height:100%;max-width:100%;max-height:100%;object-fit:\(objectFit);border:0;margin:0;padding:0"
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="\(viewport)">
        <style>
        html,body{margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;background:\(fullscreen ? "#000" : "transparent");-webkit-text-size-adjust:100%}
        \(rootStyle)
        #dkmads-root > *{max-width:100%;max-height:100%;box-sizing:border-box}
        #dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root svg,#dkmads-root canvas,#dkmads-root a{
          \(mediaStyle)
        }
        </style>
        </head><body><div id="dkmads-root">\(adm)</div></body></html>
        """
    }

    /// Banner slots — letterbox with contain.
    static let viewportInjectionScript = """
    (function(){
      var meta = document.querySelector('meta[name=viewport]');
      if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      if (document.documentElement) { document.documentElement.style.margin='0'; document.documentElement.style.width='100%'; document.documentElement.style.height='100%'; document.documentElement.style.overflow='hidden'; }
      if (document.body) { document.body.style.margin='0'; document.body.style.width='100%'; document.body.style.height='100%'; document.body.style.overflow='hidden'; }
      var imgs = document.querySelectorAll('img,iframe,video');
      for (var i = 0; i < imgs.length; i++) {
        imgs[i].style.maxWidth = '100%';
        imgs[i].style.maxHeight = '100%';
        imgs[i].style.objectFit = 'contain';
      }
    })();
    """

    /// Fullscreen interstitial — fit creative inside the slot, black letterbox fill.
    static let fullscreenViewportInjectionScript = """
    (function(){
      var meta = document.querySelector('meta[name=viewport]');
      if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
      meta.content = 'width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      var fill = 'margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;background:#000';
      if (document.documentElement) { document.documentElement.style.cssText = fill; }
      if (document.body) { document.body.style.cssText = fill; }
      var root = document.getElementById('dkmads-root');
      if (root) {
        root.style.cssText = 'margin:0;padding:0;width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000;box-sizing:border-box';
        var kids = root.children;
        for (var k = 0; k < kids.length; k++) {
          kids[k].style.maxWidth = '100%';
          kids[k].style.maxHeight = '100%';
          kids[k].style.boxSizing = 'border-box';
        }
      }
      var media = document.querySelectorAll('#dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root canvas,#dkmads-root svg,img,iframe,video,canvas,svg');
      for (var i = 0; i < media.length; i++) {
        media[i].style.cssText = 'display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border:0;margin:0;padding:0';
      }
    })();
    """
}
