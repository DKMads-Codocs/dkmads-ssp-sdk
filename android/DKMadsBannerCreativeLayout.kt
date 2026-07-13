package com.dkmads.ssp

import android.os.Build
import android.webkit.WebSettings

internal object DKMadsBannerCreativeLayout {
    /** IAB token for `/v1/bid` — from [setAdSize] / `load(sizes=…)` only, never view bounds. */
    fun bidSlotSize(adWidth: Int, adHeight: Int): Pair<Int, Int> {
        if (adWidth > 0 && adHeight > 0) return adWidth to adHeight
        return 300 to 250
    }

    /** Viewport for WebView / contain — laid-out bounds when available, else IAB fallback. */
    fun renderSlotSize(adWidth: Int, adHeight: Int, viewWidth: Int, viewHeight: Int): Pair<Int, Int> {
        if (viewWidth > 0 && viewHeight > 0) return viewWidth to viewHeight
        return bidSlotSize(adWidth, adHeight)
    }

    /** WebView settings required for hosted HTML5 ZIP packages (animations, localStorage, autoplay). */
    fun configureWebViewForRichMedia(settings: WebSettings) {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            @Suppress("DEPRECATION")
            settings.mediaPlaybackRequiresUserGesture = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }
    }

    /**
     * Hosted HTML5 packages must load at [html5EntryUrl] in the top-level WebView — not inside an
     * iframe wrapper from `adm`. The wrapper + viewport restyling froze animated creatives at their
     * first frame (industry practice: direct entry URL, MRAID/HTML5 spec).
     */
    fun resolveHtml5EntryUrl(ad: Ad): String? {
        val direct = ad.html5EntryUrl.trim()
        if (direct.isNotBlank() && ad.isHtml5 && !ad.isMraidCreative) return direct
        if (!ad.isHtml5 || ad.isMraidCreative) return null
        return extractHtml5IframeSrc(ad.adm)
    }

    private val html5IframeSrcRegex = Regex(
        """<iframe[^>]+src\s*=\s*["']([^"']+)["']""",
        RegexOption.IGNORE_CASE,
    )

    private fun extractHtml5IframeSrc(adm: String): String? {
        val src = html5IframeSrcRegex.find(adm.trim())?.groupValues?.getOrNull(1)?.trim().orEmpty()
        if (src.isBlank()) return null
        return src.takeIf { AdMediaParsing.isHtml5AssetUrl(it) }
    }

    /** Viewport meta only — never restyle creative DOM (breaks HTML5/CSS/JS animations). */
    fun html5PackageViewportScript(slotWidth: Int, slotHeight: Int): String {
        val w = slotWidth.coerceAtLeast(1)
        val h = slotHeight.coerceAtLeast(1)
        return """
            (function(){
              var meta = document.querySelector('meta[name=viewport]');
              if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
              meta.content = 'width=$w, height=$h, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            })();
        """.trimIndent()
    }

    /** Fullscreen hosted HTML5 — device viewport only; do not mutate inner creative nodes. */
    const val HTML5_FULLSCREEN_VIEWPORT_SCRIPT = """
        (function(){
          var meta = document.querySelector('meta[name=viewport]');
          if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
          meta.content = 'width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        })();
    """

    @Deprecated("Use bidSlotSize for bids and renderSlotSize for viewport", ReplaceWith("renderSlotSize(adWidth, adHeight, viewWidth, viewHeight)"))
    fun effectiveSlotSize(adWidth: Int, adHeight: Int, viewWidth: Int, viewHeight: Int): Pair<Int, Int> =
        renderSlotSize(adWidth, adHeight, viewWidth, viewHeight)

    fun htmlForFullscreen(adm: String): String {
        val fragment = extractRenderableFragment(adm)
        val bg = DKMadsCreativeChrome.LETTERBOX_BG_CSS
        return """
            <!DOCTYPE html>
            <html><head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
            html,body{margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;background:$bg;-webkit-text-size-adjust:100%}
            #dkmads-root{width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box;background:$bg}
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
        val fragment = extractRenderableFragment(adm)
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
            #dkmads-root > *{max-width:100%;max-height:100%;box-sizing:border-box}
            #dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root svg,#dkmads-root canvas{
              display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border:0;margin:0;padding:0
            }
            </style>
            </head><body><div id="dkmads-root">$fragment</div></body></html>
        """.trimIndent()
    }

    fun fullscreenClickThroughInjectionScript(clickUrl: String): String? {
        val trimmed = clickUrl.trim()
        if (trimmed.isBlank()) return null
        val escaped = trimmed.replace("\\", "\\\\").replace("'", "\\'")
        return """
            (function(){
              var url = '$escaped';
              var root = document.getElementById('dkmads-root') || document.body;
              if (!root) return;
              root.addEventListener('click', function(e) {
                if (e.target && e.target.closest && e.target.closest('a[href]')) return;
                window.location.href = url;
              }, false);
            })();
        """.trimIndent()
    }

    const val FULLSCREEN_VIEWPORT_INJECTION_SCRIPT = """
        (function(){
          function dkmadsSkipVideoStageMedia(el){
            if(!el||!el.closest)return false;
            return !!el.closest('.dkmads-video-stage,.dkmads-video-blur-stack,.dkmads-chrome');
          }
          var meta = document.querySelector('meta[name=viewport]');
          if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
          meta.content = 'width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          var fill = 'margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;background:rgba(0,0,0,0.9)';
          if (document.documentElement) { document.documentElement.style.cssText = fill; }
          if (document.body) { document.body.style.cssText = fill; }
          var root = document.getElementById('dkmads-root');
          if (root) {
            root.style.cssText = 'margin:0;padding:0;width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:rgba(0,0,0,0.9);box-sizing:border-box';
            var kids = root.children;
            for (var k = 0; k < kids.length; k++) {
              kids[k].style.maxWidth = '100%';
              kids[k].style.maxHeight = '100%';
              kids[k].style.boxSizing = 'border-box';
            }
          }
          var media = document.querySelectorAll('#dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root canvas,#dkmads-root svg,img,iframe,video,canvas,svg');
          for (var i = 0; i < media.length; i++) {
            if (dkmadsSkipVideoStageMedia(media[i])) continue;
            media[i].style.cssText = 'display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border:0;margin:0;padding:0';
          }
        })();
    """

    /**
     * Slot-sized viewport + contain for banner/HTML slots.
     * Does not rewrite media inside `.dkmads-video-stage` — that was wiping packaged Skip/mute chrome.
     */
    fun viewportInjectionScript(slotWidth: Int, slotHeight: Int): String {
        val w = slotWidth.coerceAtLeast(1)
        val h = slotHeight.coerceAtLeast(1)
        return """
            (function(){
              function dkmadsSkipVideoStageMedia(el){
                if(!el||!el.closest)return false;
                return !!el.closest('.dkmads-video-stage,.dkmads-video-blur-stack,.dkmads-chrome');
              }
              var meta = document.querySelector('meta[name=viewport]');
              if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; (document.head||document.documentElement).appendChild(meta); }
              meta.content = 'width=$w, height=$h, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
              if (document.documentElement) { document.documentElement.style.margin='0'; document.documentElement.style.width='100%'; document.documentElement.style.height='100%'; document.documentElement.style.overflow='hidden'; }
              if (document.body) { document.body.style.margin='0'; document.body.style.width='100%'; document.body.style.height='100%'; document.body.style.overflow='hidden'; }
              var root = document.getElementById('dkmads-root');
              if (root) {
                root.style.cssText = 'margin:0;padding:0;width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box';
              }
              var media = document.querySelectorAll('#dkmads-root img,#dkmads-root iframe,#dkmads-root video,#dkmads-root canvas,#dkmads-root svg,img,iframe,video,canvas,svg');
              for (var i = 0; i < media.length; i++) {
                if (dkmadsSkipVideoStageMedia(media[i])) continue;
                media[i].style.cssText = 'display:block;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border:0;margin:0;padding:0';
              }
            })();
        """.trimIndent()
    }
}
