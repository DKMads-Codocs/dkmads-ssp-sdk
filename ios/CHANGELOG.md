# Changelog

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
