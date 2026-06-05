package com.dkmads.ssp

internal object DKMadsBannerCreativeLayout {
    fun effectiveSlotSize(adWidth: Int, adHeight: Int, viewWidth: Int, viewHeight: Int): Pair<Int, Int> {
        if (viewWidth > 0 && viewHeight > 0) return viewWidth to viewHeight
        if (adWidth > 0 && adHeight > 0) return adWidth to adHeight
        return 300 to 250
    }

    fun htmlForFullscreen(adm: String): String {
        val fragment = extractRenderableFragment(adm)
        return """
            <!DOCTYPE html>
            <html><head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
            html,body{margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;background:#000;-webkit-text-size-adjust:100%}
            #dkmads-root{width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box;background:#000}
            #dkmads-root > *{max-width:100%;max-height:100%;box-sizing:border-box}
            #dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root svg,#dkmads-root canvas{
              display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border:0;margin:0;padding:0
            }
            </style>
            </head><body><div id="dkmads-root">$fragment</div></body></html>
        """.trimIndent()
    }

    private fun extractRenderableFragment(adm: String): String {
        val trimmed = adm.trim()
        val lower = trimmed.lowercase()
        if (!lower.contains("<html") && !lower.contains("<!doctype")) return trimmed
        val bodyRegex = Regex("(?is)<body[^>]*>(.*)</body>")
        return bodyRegex.find(trimmed)?.groupValues?.get(1)?.trim() ?: trimmed
    }

    fun htmlForBanner(adm: String, slotWidth: Int, slotHeight: Int): String {
        if (adm.lowercase().contains("<html")) return adm
        val w = slotWidth.coerceAtLeast(1)
        val h = slotHeight.coerceAtLeast(1)
        return """
            <!DOCTYPE html>
            <html><head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=$w, height=$h, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
            html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;-webkit-text-size-adjust:100%}
            #dkmads-root{width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box}
            #dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root svg,#dkmads-root canvas{
              display:block;max-width:100%;max-height:100%;width:100%;height:100%;object-fit:contain;border:0
            }
            </style>
            </head><body><div id="dkmads-root">$adm</div></body></html>
        """.trimIndent()
    }

    const val FULLSCREEN_VIEWPORT_INJECTION_SCRIPT = """
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

    const val VIEWPORT_INJECTION_SCRIPT = """
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
