# Ad formats reference

Supported creative formats across the dashboard, bid API, and SDKs.

**Related:** [Implementation guide](./SDK_IMPLEMENTATION_GUIDE.md) · [Platform parity](./PLATFORM_ALIGNMENT.md)

## Summary

| Format | Dashboard ad unit | Creative types | Web SDK | iOS | Android |
|--------|-------------------|----------------|---------|-----|---------|
| **Banner** | `banner` | Image, tag, HTML5 | `SSP.bind` | `DKMadsBannerAdView` | `DKMadsBannerAdView` |
| **Interstitial** | `interstitial` | Image, tag, HTML5, video | `SSP.displayInterstitial` | `DKMadsInterstitialAd` | `DKMadsInterstitialAd` |
| **Native** | `native` | Image, tag | `SSP.bind` / fluid slot (`native_assets` from bid `meta`) | `DKMadsNativeAd` / `DKMadsNativeAdView` | `DKMadsNativeAd` |
| **Video** | `video` | MP4 upload | `SSP.bindVideo()` | `DKMadsVideoAdController` | `DKMadsVideoAdController` |
| **Rewarded** | `rewarded` | Video creative | `bindVideo` + app logic | Video APIs | Video APIs |
| **Splash** | `splash` | Video / image | Slot | `DKMadsAppOpenAd` | `DKMadsAppOpenAd` |
| **Audio** | `audio` | MP3/M4A | `SSP.bindAudio()` | `loadAd(.audio)` | `loadAd` |

## Bid response (all formats)

Successful fills return JSON from `POST /api/public/v1/bid`:

```json
{
  "reason": "won",
  "winner": {
    "adm": "<html>…</html>",
    "w": 300,
    "h": 250,
    "video_url": "https://…",
    "audio_url": "https://…",
    "image_url": "https://…",
    "click_url": "https://…"
  }
}
```

- Render **`winner.adm`** in a WebView (mobile) or inject into your slot (web).
- If only **`winner.image_url`** is present, use an image view.
- **VAST XML** may be returned for video, rewarded, splash, or audio when the ad unit format requires it, or when you pass `response_format=vast`.

## Web publisher

```html
<script async src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_INTEGRATION_KEY"></script>
<div data-ssp-ad-unit="AD_UNIT_UUID" data-ssp-size="300x250"></div>
```

| API | Use for |
|-----|---------|
| `SSP.bind(el)` | Banner / display / native (auto card when `unit_format` is `native`) |
| `SSP.bindVideo(videoEl, opts)` | Instream / outstream video |
| `SSP.bindAudio(audioEl, opts)` | Audio units |
| `SSP.createInstreamLoader(...)` | Pause content during ad breaks |
| `SSP.displayInterstitial` / `SSP.displaySplash` | Fullscreen interstitial / splash |
| `SSP.canRequestAds` / `SSP.lastBidDiagnostics` | Consent gate / bid QA (parity with mobile inspector lite) |

See [integration/web.md](./integration/web.md).

## Mobile SDKs

| Format | iOS | Android |
|--------|-----|---------|
| Banner | `DKMadsBannerAdView` | `DKMadsBannerAdView` |
| Interstitial | `DKMadsInterstitialAd` | `DKMadsInterstitialAd` |
| Video / instream | `DKMadsVideoAdView`, `DKMadsInstreamAdsLoader` | Same + `DKMadsContentPlayback` |
| Audio | `loadAd` + player or `adm` | `DKMadsAudioAdView` |

Flutter and Unity use native bridges — see [integration/flutter.md](./integration/flutter.md) and [integration/unity.md](./integration/unity.md).

## Events (video & audio)

| Family | Examples | Used for |
|--------|----------|----------|
| Video | `video_start`, `video_25` … `video_100`, `video_viewable` | Quartiles, viewability |
| Audio | `audio_start`, `audio_25` … `audio_100` | Audio completion |

Full list: [SDK_METRICS_REFERENCE.md](./SDK_METRICS_REFERENCE.md).

## Video layouts (CTA / click-through)

Video creatives can include optional **CTA label** and **companion image** in the dashboard upload form. The bid response may include `video_template`, `cta_label`, and `placement_context` for native styling.

Video clicks are tracked via dedicated click events (not the whole player surface) — see metrics reference.

## Platform notes

- **Flutter / Unity:** bridge-only; use native interstitial/video APIs where banner viewability widgets are not available.
- **External exchange demand:** audio OpenRTB from third-party buyers may be limited; house and VAST paths support audio today.

## Related

- [SDK Implementation Guide](./SDK_IMPLEMENTATION_GUIDE.md)
- [Platform parity](./PLATFORM_ALIGNMENT.md)
- [SDK Integration Checklist](./SDK_INTEGRATION_CHECKLIST.md)
