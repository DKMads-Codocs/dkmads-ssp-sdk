# Changelog

## 0.5.30

- **Skip stays for the whole ad (real fix):** WebView viewport injection no longer rewrites `<video>` styles inside `.dkmads-video-stage`, which was collapsing packaged Skip/mute chrome a few seconds after load.
- Native: Skip stays above CTA/companion; countdown no longer uses disabled styling that can hide the label.

## 0.5.29

- **Skip stays visible:** companion image and click overlay no longer cover Skip/mute; chrome is kept on top for the entire ad.
- Companion sits above the chrome bar with clearance so Skip remains tappable after the image loads.

## 0.5.28

- **Single chrome owner:** if WebView ADM already includes packaged `.dkmads-chrome-*` (skip/mute/progress), do not add native Skip/mute/progress.
- **iOS native Skip UX:** countdown parity with Android (`Skip in Xs` → `Skip`).

## 0.5.27

- **P0:** Fix `DKMadsVideoAdView` crash — `playerView` is added to the hierarchy before Auto Layout constraints (was missing `addSubview`).
- **P0:** Raise initial video load timeout to **45s** (stall timeout **20s**) for large progressive house MP4s.
- **P1:** `DKMadsAdError.nsError(userInfo:)` preserves caller `NSLocalizedDescriptionKey` (timeouts no longer show as generic “Video playback failed.”).
- **P1:** Native MP4/HLS failure falls back to WebView when `adm` contains `<video>`.

## 0.5.26

- **Interstitial HTML5 packages:** center + scale hosted `html5_entry_url` creatives to fit the screen (outer WebView transform / letterbox). Package-sized viewport only — creative DOM is not rewritten. Fixes top-left 320×480 on fullscreen.

## 0.5.25

- **`contain_blur` instream fit:** 1:1 (and other) creatives center inside the player with a glass-blur video backdrop (`slot_fit: contain_blur` from ad unit targeting).
- **Bid parity:** parses `slot_fit`, `slot_w`, `slot_h` on video wins; native MP4 uses dual-player blur; packaged HTML ADM with `dkmads-slot-fit-blur` loads as-is.

## 0.5.24

- **GitHub mirror parity** — publisher-repo release sync (Phase 15 + S2). See monorepo notes if you were on stale `sdk-0.5.23` tag.
- **`linkDmpIdentity` / `coInitDmp` / `dmpAppKey`:** identity bridge + `identitySourceLabel()` for support.
- **`hasFill`:** structured `native_assets` without `adm` / `creativeUrl` count as fill.
- **DMP integration docs** shipped under `docs/integration/`.

## 0.5.23

- **DMP co-init:** `SSPSDKConfig.dmpAppKey` / `dmpApiHost` — async DMP init when `DKMadsDMP` is linked, then `linkDmpIdentity`.
- **`linkDmpIdentity` / `coInitDmp`:** identity bridge + `identitySourceLabel()` for support.
- **`hasFill`:** structured `native_assets` without `adm` / `creativeUrl` count as fill.
- **OMID:** image interstitial already had native display sessions (unchanged).

## 0.5.22

- **Render mode contract:** banner/native/interstitial honor the server `render_mode` hint as the primary render fork, with existing heuristics as fallback.
- **MRAID 2.0:** WebView creatives that reference `mraid.js` get the MRAID bridge installed on banner, native HTML, and interstitial paths.
- **Open Measurement (OMID) adapter seam:** new `DKMadsOmid` provider registry drives session lifecycle (start, loaded, impression, video start/quartiles/complete/skip, finish) on display and video placements when an OM SDK adapter is registered. No-op when unregistered.
- **Native assets:** `native_assets` from the winner are parsed without client-side `adm` parsing.

## 0.5.21

- Banner/interstitial `hasFill` no longer blocked by stray `video_template` on image/HTML house wins.

## 0.5.20

- Compact video chrome (28px mute/skip, 12px CTA) aligned with Android 0.5.20.

## 0.5.19

- Video `loaded` / `hasFill` aligned with `hasVideoRenderableContent`; video placements never classified as HTML5.
- Bid parsing fallbacks (nested creative, `image_url` stream → `video_url`).

## 0.5.18

- **`hasFill` / video validation:** renderable fill only (`html5_entry_url`, playable `video_url`, VAST/HTML video `adm`); `delivery_type: video` alone no longer counts.
- **`playableVideoURL`:** hosted HLS (`…/hls/master.m3u8`), VAST `<MediaFile>`, extensionless creative-assets paths.
- **`hasVideoRenderableContent`:** `DKMadsVideoAdView` uses this instead of `isVideo` for load guards.

## 0.5.17

- **Bid vs render split:** `bidSlotSize()` for bids; `renderSlotSize()` for WebView viewport. `load(bidSize:)` override on banner/video.
- `updateAdSize(_:)` is IAB metadata only — layout via Auto Layout constraints.

## 0.5.16

- **Responsive contain layout:** banner images use `scaleAspectFit` (no crop); HTML banners use slot-sized viewport + `object-fit: contain`.
- Full HTML `adm` re-wrapped for banners; video WebView `adm` uses contain shell + slot viewport injection.

## 0.5.15

- **Instream unmute:** `DKMadsVideoChrome.isInstreamPlacement` treats `placementContext` values like `instream_preroll` as instream (`contains("instream")`); falls back to the `load()` placement when the bid omits `placement_context`.
- Load-generation tokens on `DKMadsVideoAdView` and `DKMadsBannerAdView` (ignore stale bid callbacks after `display()` / new `load()`).

## 0.5.14

- Fullscreen letterbox / interstitial chrome uses **90% opaque black** (`rgba(0,0,0,0.9)`) instead of solid `#000`.

## 0.5.13

- Platform parity release (Android interstitial placement defaults, web interstitial fit + click-through). See Android / web changelogs.

## 0.5.12

- Fix interstitial clicks: remove full-screen chrome overlay that blocked WebView/image taps; close (✕) only captures its own hit area.
- HTML interstitial: open any landing-page link (not only exact `click_url` match); tap-to-click fallback when creative has no embedded link.

## 0.5.11

- Interstitial fullscreen: switch from `object-fit:cover` to `contain` — creative fits on screen without horizontal clipping; black letterbox on mismatch.
- Image/video interstitial use aspect-fit (not aspect-fill).

## 0.5.10

- Interstitial HTML: always re-wrap full `<html>` adm, use `object-fit:cover` + device viewport (fixes top-half creative + white bottom).
- Defer static interstitial render until layout bounds are known; opaque black WebView background.
- Interstitial `load()`: default `placementCode` / `placementContext` when omitted (same as banner).

## 0.5.9

- Interstitial presenter: constraint-based fullscreen layout, responsive HTML/image scaling, `prefersAspectFill` video.
- Close (✕) lives in a dedicated chrome overlay always brought to front (fixes disappearing under WebView/video).
- Interstitial video uses presenter close only (`isSkippable = false`); no competing skip control.

## 0.5.8

- Fix compile: `load()` uses non-optional `effectiveRequest` after `normalizedRequest()` (remove erroneous `?.`).

## 0.5.7

- Fix compile: rename banner `setAdSize(_:)` → `updateAdSize(_:)` (`@objc(updateAdSize:)`) — avoids ObjC selector clash with `adSize` property setter.
- Banner: default `placementCode` / `placementContext` when omitted; bid JSON omits null placement fields.
- iOS integration guide + sample updated with required `DKMadsAdRequest`, delegate, and `rootViewController`.

## 0.5.6

- Banner view reports `intrinsicContentSize` for Auto Layout; bid + render use laid-out bounds when available. (Use `updateAdSize(_:)` in 0.5.7+ — 0.5.6 `setAdSize(_:)` did not compile.)
- Banner HTML/image creatives scale to the slot (responsive viewport wrapper + `scaleAspectFill` images).

## 0.5.5

- Interstitial/video: accept hosted `/api/public/creative-assets/` URLs without file extensions (`playableVideoURL` — matches server + Android).
- Image interstitials: resolve hosted creative-assets paths in `creativeUrl`.
- Interstitial reload preserves last `DKMadsAdRequest`; ObjC `loadInterstitialWithAdUnitID:adWidth:adHeight:request:completion:`.

## 0.5.4

- Banner auto-refresh reuses the last `DKMadsAdRequest` (placement + `keyValues` including `test_mode`).
- `DKMadsInstreamAdsLoader.requestAds` accepts an optional `DKMadsAdRequest`; `useTestAds` injects `test_mode` into bid `key_values`.
- Native video (HLS/MP4): 15s initial load timeout, buffering delegate callbacks, 12s stall fail-fast.

## 0.5.3

- Restore `SSPSDK.registeredSizes(for:)` for interstitial / app open IAB bid tokens (used by `DKMadsInterstitialAd.bidSizes`).
- Click-through CTA uses `addTarget` instead of `UIButton.addAction` (iOS 13 deployment target).
- ObjC `setConsentGdpr:…gppSid:` converts `NSNumber` to `String` for `ConsentData.gppSid`.

## 0.5.2

- Fix Xcode compile: `SDKError.consentRequired` / `adExpired` for `DKMadsAdError.from(_:)`.
- `DKMadsInterstitialPresenter` moved to shared module file (app open can present splash).
- `DKMadsRewardedAd`: Swift-only `load(adSize:)`; ObjC uses `loadRewardedWithAdUnitID:request:completion:`.
- Consent gate returns `SDKError.consentRequired` when `requireConsentBeforeAds` blocks bids.

## 0.5.1

- `DKMadsNativeAd` + `DKMadsNativeAdAssets` (`Ad.nativeAssets`); `DKMadsAdCachePolicy` fullscreen expiry.
- `DKMadsAppOpenAd` (splash), Ad Inspector v2, `DKMadsAdError.adExpired`.
- Flutter `loadNative` bridge returns native asset fields from bid payload.

## 0.5.0

- Ad Inspector, `DKMadsAdSize` adaptive helpers, iOS native/audio views, unified fullscreen delegate.
- ObjC bridges for `loadAd`, consent, targeting, FPD; bid `refresh_interval_sec` on banners.
- Flutter/Unity 0.5.0: banner PlatformView, Unity video events + FPD sync.

## 0.4.2

- Version aligned with Android `0.4.2` for unified publisher releases (`sdk-0.4.2`).

## 0.4.1

- Version aligned with Android `0.4.1` for unified publisher releases (`sdk-0.4.1`).

## 0.4.0

- `DKMadsInterstitialAd`: fullscreen video, image, HTML5, and `adm`; IAB bid sizes (explicit → `registerAdUnit` → 320×480).
- `Ad`: `video_url`, `hasFill`, `isVideo`, `isHTML5`, `preferredPlaybackURL` for house/video creatives.
- `SSPSDK.registeredSizes(for:)` for interstitial size tokens.

## 0.3.1

- Added `TargetingSignals` model and `SSPSDK.setTargetingSignals(_:)` for structured bid/FPD targeting.
- Added `SSPSDK.syncFirstPartyProfile()` to push interests/keywords to `/api/public/v1/fpd/mobile`.
- Telemetry events now attach `user_pid` / `device_pid` from the identity provider when set.
- Unity bridge: `dkmads_set_targeting_signals` C entry point for structured targeting JSON.
- Public API paths centralized in `PublicAPIPaths` (`bid`, `events`, `fpd/mobile`).

## 0.3.0

- Restructured SDK into `Sources/DKMadsSSPSDK` modules (Core, Models, Network, UI, Telemetry).
- Added `DKMadsMobileAds` entry point (`start` for one-time SDK bootstrap).
- Added `DKMadsBannerAdView` with WebView/image rendering and click handling.
- Added `DKMadsResponseInfo` for fill diagnostics (`reason`, `request_id`, `dsp`, `price`).
- Added Swift Package Manager (`Package.swift`) and fixed CocoaPods source paths.
- Added sample app scaffold under `Sample/`.
- Fixed consent initialization and main-thread ad callbacks.
