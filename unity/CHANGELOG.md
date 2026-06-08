# Changelog

## 0.5.14

- Tracks native SDK **0.5.14** (90% opaque letterbox backgrounds).

## 0.5.13

- Tracks native SDK **0.5.13** (interstitial fit + click-through parity on iOS/Android).

## 0.5.1

- `LoadNative`, `LoadAppOpen`, `ShowAppOpen`, `PresentAdInspector`.
- Quickstart sample: banner JSON + inspector context menu.
- Tracks native SDK 0.5.1.

## 0.5.0

- `TrackVideoLifecycle` forwards to native telemetry; `SyncFirstPartyProfile` bridge.
- Tracks native SDK 0.5.0.

## 0.2.0

- Added `LoadInterstitial` + `ShowInterstitial` (Android + iOS native fullscreen).
- Added `LoadAdWithFormat` and iOS `dkmads_load_ad` bridge (banner, interstitial, video, …).
- Load JSON includes `videoUrl`, `html5EntryUrl`, `isVideo`, `isHtml5`.
- Aligned with native SDK v0.4.2.

## 0.1.0

- Initial bridge: init, targeting, `LoadAd` (Android), video event forwarding.
