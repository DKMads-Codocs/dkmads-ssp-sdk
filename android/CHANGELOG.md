# Changelog

## 0.5.28

- **Single chrome owner:** if WebView ADM already includes packaged `.dkmads-chrome-*`, load ADM as-is and skip native Skip/mute/progress (no duplicate Skip).
- Native MP4 path unchanged — countdown Skip only.

## 0.5.27

- **P0:** Raise initial video load timeout to **45s** (stall timeout **20s**) for large progressive house MP4s.
- **P1:** Native MP4/HLS failure falls back to WebView when `adm` contains `<video>`.

## 0.5.26

- **Interstitial HTML5 packages:** center + scale hosted `html5_entry_url` creatives to fit the screen (outer WebView scale / letterbox). Package-sized viewport only — creative DOM is not rewritten. Fixes top-left 320×480 on fullscreen (also app open / rewarded presenters).

## 0.5.25

- **`contain_blur` instream fit:** centered creative + blurred zoomed backdrop for square instream in responsive players (`slot_fit` from bid).
- **Bid parity:** `slot_fit` / `slot_w` / `slot_h` on `Ad`; API 31+ uses `RenderEffect` blur, older devices use zoom + dim fallback.

## 0.5.24

- **GitHub mirror parity:** first publisher-repo release containing Phase 15 + S2 identity bridge (prior tag `sdk-0.5.23` on GitHub was stale).
- **`linkDmpIdentity` / `useDmpIdentity` / `dmpAppKey`:** DMP ↔ SSP identity for bid-time audience eval.
- **`hasFill`:** structured `native_assets` without `adm` / `creativeUrl` count as fill.
- **DMP docs:** `docs/integration/dmp-identity.md`, `dmp-co-init.md`, and related guides included in publisher repo.
- **Sample:** `samples/dmp-ssp-identity/` — `DMP.getSharedIdentity()` → `linkDmpIdentity()`.

## 0.5.23

- **DMP co-init:** optional `dmpAppKey` / `dmpApiHost` on `Config` — reflection-based DMP init + `linkDmpIdentity`.
- **`linkDmpIdentity` / `coInitDmp`:** share DMP `device_pid` / `user_pid` with SSP for bid-time eval.
- **`hasFill`:** `native_assets`-only wins (no `adm` / `creativeUrl`) count as fill.
- **OMID:** image interstitial path starts native display OMID session (parity with banner + iOS).

## 0.5.22

- **Render mode contract:** banner/native/interstitial honor the server `render_mode` hint as the primary render fork, with existing heuristics as fallback.
- **MRAID 2.0:** WebView creatives that reference `mraid.js` get the MRAID bridge injected on banner, native HTML, and interstitial paths.
- **Open Measurement (OMID) adapter seam:** new `DKMadsOmid` provider registry drives session lifecycle (start, loaded, impression, video start/quartiles/complete/skip, finish) on display and video placements when an OM SDK adapter is registered. No-op when unregistered.
- **Native assets:** `native_assets` from the winner are parsed into `DKMadsNativeAdAssets` without client-side `adm` parsing.

## 0.5.21

- **`hasFill` on banner/interstitial:** image/HTML wins no longer require video when `video_template` metadata is present; placement uses `unit_format` + `delivery_type` + playable content, not `video_template` alone.
- **Server:** `video_template` omitted from `/v1/bid` winner for non-video display slots (banner/interstitial/native image/HTML).

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
