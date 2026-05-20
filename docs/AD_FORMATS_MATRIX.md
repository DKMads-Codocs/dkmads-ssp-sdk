# Ad formats matrix (Banner · Video · Audio)

Cross-stack map of where each format is defined, created, served, rendered, and measured.

## Summary

| Format | Dashboard ad unit | Creative upload | House bid `adm` | Public `/v1/bid` | Web SDK | iOS SDK | Android SDK |
|--------|-------------------|-----------------|-----------------|------------------|---------|---------|-------------|
| **Banner** | Ad Units → `banner` | Image / tag / HTML5 | `<img>` HTML | JSON `winner.adm` | `SSP.bind` (auto viewable) | `DKMadsBannerAdView` (auto viewable) | `DKMadsBannerAdView` (auto viewable) |
| **Interstitial** | `interstitial` | Image / tag / HTML5 | Same as banner | JSON | `SSP.displayInterstitial` | `DKMadsInterstitialAd` (video, image, HTML5) | `DKMadsInterstitialAd` (video, image, HTML5) |
| **Native** | `native` | Image / tag | Image/HTML | JSON | Fluid slot | `loadAd(.native)` | `loadAd` |
| **Video** | `video` | MP4 upload | `<video>` HTML | JSON or **VAST XML** | `SSP.bindVideo()` | `DKMadsVideoAdController` | `DKMadsVideoAdController` |
| **Rewarded** | `rewarded` | Video creative | Video HTML | JSON / VAST | `bindVideo` + app logic | Video APIs | Video APIs |
| **Splash** | `splash` | Video / image | Video/image HTML | JSON / VAST | Slot | `loadAd` | `loadAd` |
| **Audio** | `audio` (new) | MP3/M4A upload | `<audio>` HTML | JSON / VAST (audio) | `SSP.bindAudio()` | `loadAd(.audio)` | `loadAd` |

## Backend (Node)

| Path | Role |
|------|------|
| `server/lib/ad-formats.js` | Canonical format list + compatibility aliases |
| `server/lib/dsp/house.js` | Builds `adm` for image, video, audio |
| `server/index.js` | `executeBidAuction`, `buildVastXml`, creative validation |
| `server/routes/public-ad.js` | `POST /api/public/v1/bid`, `POST /v1/events` |
| `server/lib/openrtb.js` | `imp.banner` vs `imp.video` for external DSP |
| `server/lib/waterfall.js` | Tier execution (all formats) |
| `database/schema.sql` | `ad_units.format`, `creatives.type` |

### Bid response fields

```json
{
  "reason": "won",
  "winner": {
    "adm": "<html>…</html>",
    "w": 300,
    "h": 250,
    "video_url": "…",
    "audio_url": "…",
    "dsp": "house_ads"
  }
}
```

- **VAST** auto-returned when ad unit format is `video`, `rewarded`, `splash`, or `audio`, or `response_format=vast`.

## Frontend (React dashboard)

| Path | Role |
|------|------|
| `src/pages/AdUnits.tsx` | Ad unit format picker |
| `src/pages/Creatives.tsx` | Creative list / filters |
| `src/components/creatives/CreativeUploadDialog.tsx` | Upload by delivery mode |
| `src/lib/creative-upload-spec.ts` | Image / video / **audio** rules |
| `src/lib/ad-formats.ts` | Canonical format list (mirrors `server/lib/ad-formats.js`) |
| `src/lib/ad-size-catalog.ts` | IAB sizes + video + audio groups |
| `src/components/campaigns/builder/*` | Campaign line creatives |
| `src/pages/Waterfall.tsx` | Simulation (all formats) |

## Web publisher SDK

| Path | Role |
|------|------|
| `public/sdk/ssp-sdk.js` | Init, slots, `bindVideo`, **`bindAudio`**, viewability |

Embed: `<script src="/sdk/ssp-sdk.js">` + `data-ssp-ad-unit`.

## Mobile SDKs

| Path | Role |
|------|------|
| `sdk/ios/` | `DKMadsBannerAdView`, `DKMadsInterstitialAd`, video lifecycle |
| `sdk/android/` | Banner, interstitial, `DKMadsVideoAdView`, `DKMadsInstreamAdsLoader`, native, audio |
| `sdk/flutter/`, `sdk/unity/` | Bridges: `loadBanner`, `loadInterstitial` + `showInterstitial` (iOS/Android) |

## Event telemetry (video + audio)

| Event family | Web SDK | iOS/Android |
|--------------|---------|-------------|
| Video | `video_start`, `video_25`…`video_100`, `video_viewable` | `trackVideoLifecycle` |
| Audio | `audio_start`, `audio_25`…`audio_100`, `audio_pause` | Use `trackUserEvent` or web parity |

## Deploy checklist

1. Apply DB migrations (if any pending under `database/migrations/`).
2. Deploy API (`server/index.js` + `public-ad` routes).
3. Build frontend: `pnpm run build:prod`.
4. Publish mobile SDK tags / CocoaPods path.
5. Verify curl bid per format (see `docs/SDK_INTEGRATION_CHECKLIST.md`).

## Known gaps (post-upgrade)

- iOS: no dedicated `DKMadsAudioAdView` (use `loadAd` + `adm` or app player + events).
- Flutter: no `PlatformView` or instream bridge — `loadInterstitial` + `showInterstitial` uses native `DKMadsInterstitialAd`; video via `emitVideoEvent`.
- Unity: no UGUI or instream bridge — `LoadInterstitial` + `ShowInterstitial` on iOS/Android; video via `EmitVideoEvent`.
- External DSP connectors: audio OpenRTB `imp.audio` not yet wired (house + VAST path works).
