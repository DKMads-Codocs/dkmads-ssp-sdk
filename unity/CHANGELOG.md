# Changelog

## 0.5.29

- Tracks native SDK **0.5.29** (Skip stays above companion / click overlay for the entire ad).

## 0.5.28

- Tracks native SDK **0.5.28** (single video chrome owner; iOS Skip countdown).

## 0.5.27

- Tracks native SDK **0.5.27** (video load timeout, native→web fallback, iOS video crash fix).

## 0.5.26

- Tracks native SDK **0.5.26** (interstitial HTML5 package center + scale letterbox).

## 0.5.25

- Tracks native SDK **0.5.25** (`contain_blur` instream glass-blur player fit).

## 0.5.24

- `DKMadsSdk.LinkDmpIdentity` + `dmpAppKey` co-init (mirror parity with native 0.5.24).
- DMP integration docs + `samples/dmp-ssp-identity/` in publisher repo.

## 0.5.23

- `DKMadsSdk.Initialize(..., dmpAppKey, dmpApiHost)` — DMP co-init on native init.
- `DKMadsSdk.LinkDmpIdentity(devicePid, userPid)` — explicit identity handoff.

## 0.5.22

- Tracks native SDK **0.5.22** (server `render_mode` hint, MRAID 2.0, OMID measurement seam, structured native assets).
- `DKMadsAdLoadResult.renderMode` surfaces the server render hint (`image` | `html5` | `video_native` | `video_web` | `native_assets` | `audio`) for custom rendering forks.
- Native interstitial / app-open / banner surfaces automatically inherit MRAID 2.0 and the OMID measurement seam from the native SDK.
- OMID providers are registered in the native host (Android `Application` / iOS `AppDelegate`); see `docs/integration/unity.md`.

## 0.5.15

- Tracks native SDK **0.5.15** (Android video parity: HLS/ExoPlayer, `playableVideoUrl`, load guards).

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
