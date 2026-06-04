# Changelog

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
