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
        let w = max(1, Int(slotSize.width.rounded()))
        let h = max(1, Int(slotSize.height.rounded()))
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=\(w), height=\(h), initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;-webkit-text-size-adjust:100%}
        #dkmads-root{width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box}
        #dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root svg,#dkmads-root canvas{
          display:block;max-width:100%;max-height:100%;width:100%;height:100%;object-fit:contain;border:0
        }
        </style>
        </head><body><div id="dkmads-root">\(adm)</div></body></html>
        """
    }

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
}
