# Changelog

## 0.5.15

- Tracks native SDK **0.5.15** (Android video parity: HLS/ExoPlayer, `playableVideoUrl`, load guards).

## 0.5.14

- Tracks native SDK **0.5.14** (90% opaque letterbox backgrounds).

## 0.5.13

- Tracks native SDK **0.5.13** (interstitial fit + click-through parity on iOS/Android).

## 0.5.2

- iOS compile fixes for publisher CocoaPods builds (see ios CHANGELOG).
- Tracks native SDK 0.5.2.

## 0.5.1

- `loadNative` + `DkmadsAdResult` headline/body/callToAction/iconUrl fields.
- `loadAppOpen`, `showAppOpen`, `presentAdInspector` (native bridges).
- Tracks native SDK 0.5.1.

## 0.5.0

- `DkmadsBannerAd` embedded banner PlatformView (auto viewability).
- Tracks native SDK 0.5.0.

## 0.2.0

- Added `loadInterstitial`, `showInterstitial`, and `registerAdUnit` (native `DKMadsInterstitialAd` on iOS/Android).
- `DkmadsAdResult` (alias `DkmadsBannerResult`) includes `videoUrl`, `html5EntryUrl`, `isVideo`, `isHtml5`, `campaignId`, `creativeId`.
- Aligned with native SDK v0.4.2 interstitial IAB bid sizes.

## 0.1.0

- Initial bridge: init, consent, targeting, `loadBanner`, video telemetry.
