# Changelog

## 0.5.3

- Restore `SSPSDK.registeredSizes(for:)` for interstitial / app open IAB bid tokens (used by `DKMadsInterstitialAd.bidSizes`).

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
