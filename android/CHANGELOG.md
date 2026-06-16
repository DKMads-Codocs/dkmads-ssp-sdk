# Changelog

## 0.5.20

- **Premium video chrome (Android):** unified bottom control row `[mute] · [Learn more] · [Skip]` with glass pills, 28dp icons, sentence-case labels (fixes oversized Material `LEARN MORE` blocking video).
- Custom speaker icon drawable; subtle bottom gradient scrim; compact CTA gradient pill matching iOS/web.
- Web + house `adm` chrome CSS tightened (28px controls, 12px CTA).

## 0.5.19

- **Video fill / Inspector parity:** `loaded` and `hasFill` for video/rewarded requests require `hasVideoRenderableContent` (playable `video_url`, video/VAST `adm`) — no more `loaded=true` when playback is rejected.
- **Video vs HTML5:** video placements (`delivery_type`, `unit_format`, `video_template`) are never classified as HTML5; `hasVideoRenderableContent` no longer blocked by false HTML5 detection.
- **Bid parsing:** camelCase `videoUrl`, nested `winner.creative`, and `image_url`→`video_url` fallback when the stream is HLS/MP4; video streams excluded from banner `creativeUrl`.
- **Server:** `resolveBidImageUrl` no longer puts HLS/MP4 in `image_url`.

## 0.5.18

- **`hasFill` / video validation:** `hasFill` requires renderable assets (`html5_entry_url`, playable `video_url`, VAST/HTML video `adm`, image `adm`, etc.); `delivery_type: video` alone no longer counts as fill.
- **`playableVideoUrl`:** accepts hosted HLS (`…/hls/master.m3u8`), extensionless creative-assets paths, VAST `<MediaFile>`, and external MP4/HLS without requiring `isVideo` first.
- **`hasVideoRenderableContent`:** new guard used by `DKMadsVideoAdView` / `DKMadsVideoAdController` instead of `isVideo` (VAST-only and `video_url`-only wins load correctly).

## 0.5.17

- **Bid vs render split:** `bidSlotSize()` for `/v1/bid` (IAB from `setAdSize` / `load(sizes=…)`); `renderSlotSize()` for WebView viewport only.
- `setAdSize()` no longer sets `layoutParams` in raw px — IAB metadata only; use layout XML for dp sizing.
- Banner/video/native `load(sizes=…)` optional bid override while rendering into responsive view bounds.

## 0.5.16

- **Responsive contain layout:** banner raster images use `FIT_CENTER` (no crop); HTML banners use slot-sized viewport + `object-fit: contain` (fixes device-width rescale).
- Full HTML `adm` documents are re-wrapped for banners (body fragment extraction).
- Video WebView `adm` uses the same contain shell; ExoPlayer explicitly uses `RESIZE_MODE_FIT`.

## 0.5.15

- **Instream unmute:** `DKMadsVideoChrome.isInstreamPlacement` treats `placementContext` values like `instream_preroll` as instream (`contains("instream")`); falls back to the `load()` placement when the bid omits `placement_context`.
- **Video parity with iOS:** ExoPlayer (Media3) for MP4 + HLS (`.m3u8`, `/hls/`) in `DKMadsVideoAdView` and video interstitials.
- `Ad.playableVideoUrl`, `Ad.preferredRenderer`, and `AdMediaParsing` (hosted creative URLs, adm `<video>` extraction).
- `DKMadsVideoAdView.load()` no longer treats `reason: "won"` as failure; validates `hasFill` + playable URL / adm separately.
- Load-generation tokens on banner + video views (ignore stale bid callbacks).
- Bid HTTP errors surface server `message` (e.g. `ad_unit not in integration property`) via `SDKError.RequestFailed`.

## 0.5.14

- Fullscreen letterbox / interstitial chrome uses **90% opaque black** (`rgba(0,0,0,0.9)`) instead of solid `#000`.

## 0.5.13

- Interstitial `load()`: default `placementCode` / `placementContext` when omitted (matches iOS).
- Banner + video WebView: open any http(s) landing URL after load (not only exact `click_url` prefix match).
- Shared `ClickThroughNavigation.shouldOpenLandingUri` helper.

## 0.5.12

- Interstitial WebView: fix click-through (any http(s) landing URL + tap-to-click fallback for non-linked creatives).

## 0.5.11

- Interstitial HTML: fullscreen re-wrap + `object-fit:contain` (fit on screen, black letterbox).
- Post-load viewport injection for interstitial WebView.

## 0.5.7

- Banner: default `placementCode` / `placementContext`; bid JSON omits null placement fields.

## 0.5.6

- Banner bid/render use measured view size; responsive HTML wrapper + `CENTER_CROP` images fill the slot.

## 0.5.4

- Banner auto-refresh reuses last load params (`placementCode`, `placementContext`, `keyValues`).
- `DKMadsInstreamAdsLoader.requestAds` accepts `placementCode` + `keyValues`; `useTestAds` injects `test_mode`.
- Native video: 15s prepare timeout, `onPlaybackBuffering`, 12s buffer stall fail-fast.

## 0.5.2

- iOS compile fixes aligned with 0.5.2 tag (consent error, app open presenter, rewarded ObjC load).

## 0.5.1

- `DKMadsNativeAd` + `DKMadsNativeAdAssets` for custom in-feed layouts.
- Fullscreen cache expiry (4h TTL); show returns `ad_expired` when stale.
- `DKMadsAppOpenAd`, Ad Inspector, splash `SPLASH` format (carried from 0.5.0 line).
- GitHub Packages Maven publish on release when `GITHUB_TOKEN` is set.

## 0.5.0

- `canRequestAds()` / `requireConsentBeforeAds`; Ad Inspector; `DKMadsAdSize`; unified fullscreen callback.
- Bid diagnostics + banner auto-refresh from `refresh_interval_sec`.

## 0.4.2

- Fixed Kotlin compile errors: `MediaPlayer.duration` (Int) uses `coerceAtLeast(0).toLong()` in `DKMadsInterstitialActivity` and `DKMadsVideoAdView` (not `coerceAtLeast(0L)`).
- `SSPSDK` telemetry payloads use explicit `mapOf<String, Any?>` / `mapOf<String, String?>` for identity maps.

## 0.4.1

- Added `DKMadsVideoAdView`, `DKMadsInstreamAdsLoader` (+ `DKMadsContentPlayback` for ExoPlayer hooks).
- Added `DKMadsResponseInfo` on banner, interstitial, video, native, and audio views/listeners.
- Added `DKMadsNativeAdView`, `DKMadsAudioAdView`; `Ad.audioUrl` / `isAudio`.
- Fixed `TelemetryManager` to use shared `SDK_VERSION` (0.4.0) instead of hardcoded `1.0.0`.

## 0.4.0

- Added `DKMadsInterstitialAd` + `DKMadsInterstitialActivity` — fullscreen video, image, HTML5, and `adm` (parity with iOS).
- Interstitial bid sizes: explicit dimensions → `registerAdUnit` sizes → default **320×480** (not display pixels).
- `SSPSDK.registerAdUnit` now stores sizes; added `registeredSizes()`.
- `Ad.isVideo` and `hasFill` aligned with iOS (`video_url`, HTML5, image, tag).

## 0.3.1

- Added `TargetingSignals` data class and `SSPSDK.setTargetingSignals()` for structured bid/FPD targeting.
- Added `SSPSDK.syncFirstPartyProfile()` for mobile FPD profile sync.
- Telemetry attaches `user_pid` / `device_pid` via `TelemetryManager.setIdentityProvider`.
- Unity bridge: `DKMadsUnityBridge.setTargetingSignals()` maps JSON to `TargetingSignals`.

## 0.3.0

- Initial public SDK module with `loadAd`, consent, telemetry, and structured response info (`reason`, `request_id`, `dsp`, `price`).
- Default production base URL: `https://ssp.dkmads.com`.
