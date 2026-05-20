# DKMads SSP — SDK implementation guide

This is the **main publisher documentation hub** for integrating DKMads across web and mobile. Use it like a product integration manual: prerequisites → initialize → request ads → measure → troubleshoot.

**Dashboard:** **Developer → SDK guide** (in-app walkthrough).  
**Fast path:** [60-minute Quickstart](./integration/QUICKSTART.md).

---

## 1. Before you integrate

### What you need from the dashboard

1. **Property** (web, iOS, or Android) — status active, integration key copied.
2. **Ad unit** — UUID, format (banner, video, …), size(s).
3. **Waterfall** — saved on the property (Demand → Waterfall).
4. **Campaign** — active line item + approved creative matching the ad unit format.

### Hostnames

| Environment | API / script base |
|-------------|-------------------|
| Production | `https://ssp.dkmads.com` |
| Your deployment | Your API origin (must serve `/api/public/v1/*` and optionally `/sdk/ssp-sdk.js`) |

Mobile SDKs call `POST {baseURL}/api/public/v1/bid` with header `X-Integration-Key`.

---

## 2. Platform packages

| Platform | Delivery | Integration guide |
|----------|----------|-------------------|
| **Web** | Hosted script (`/api/public/sp.js`) | [integration/web.md](./integration/web.md) |
| **iOS** | `DKMadsSSPSDK` — CocoaPods or SPM | [integration/ios.md](./integration/ios.md) |
| **Android** | `com.dkmads.ssp:ssp-android` | [integration/android.md](./integration/android.md) |
| **Flutter** | `dkmads_ssp` + native iOS/Android libraries | [integration/flutter.md](./integration/flutter.md) |
| **Unity** | `com.dkmads.ssp` UPM + native iOS/Android libraries | [integration/unity.md](./integration/unity.md) |

Each mobile guide includes an **Installation** section (CocoaPods, Gradle, path, or Git dependency). Web uses a single script tag—no app package install.

**Publisher SDK repository (Git):** [github.com/DKMads-Codocs/dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk)  
Releases are tagged `sdk-<semver>` (for example `sdk-0.4.1`). The platform monorepo exports SDK sources to this repo on each SDK release.

```text
ios/              → DKMadsSSPSDK (SPM / CocoaPods)
android/          → Kotlin sources
android-module/   → Gradle AAR publisher
flutter/          → dkmads_ssp plugin
unity/            → com.dkmads.ssp UPM package
docs/             → Integration guides (mirrored from platform)
```

Web script remains hosted at `https://ssp.dkmads.com/api/public/sp.js` (built from `public/sdk/ssp-sdk.js` in the platform repo).

**Operators:** release automation and security — [SDK_DISTRIBUTION.md](./SDK_DISTRIBUTION.md).

---

## 3. Integration flow (all platforms)

```text
1. Initialize SDK (once per app / page load)
2. setConsent (if GDPR / US privacy applies)
3. setTargetingSignals (optional — demographics, geo, interests)
4. Load ad OR use banner/video view component
5. Render winner.adm or winner.image_url
6. Metrics fire automatically (banner/video) or via trackUserEvent
```

Canonical contract: [SDK_CONTRACT.md](./SDK_CONTRACT.md).

---

## 4. Platform guides

| Platform | Package / asset | Guide |
|----------|-----------------|--------|
| **Web** | `ssp-sdk.js` (script tag) | [integration/web.md](./integration/web.md) |
| **iOS** | `DKMadsSSPSDK` (SPM / CocoaPods) | [integration/ios.md](./integration/ios.md) |
| **Android** | `com.dkmads.ssp` module | [integration/android.md](./integration/android.md) |
| **Flutter** | `dkmads_ssp` plugin | [integration/flutter.md](./integration/flutter.md) — `loadInterstitial` + `showInterstitial` |
| **Unity** | `sdk/unity` bridge | [integration/unity.md](./integration/unity.md) — `LoadInterstitial` + `ShowInterstitial` |

### Web — minimal tag

```html
<script>window.ssp = window.ssp || [];</script>
<script async src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_INTEGRATION_KEY"></script>
<div data-ssp-ad-unit="AD_UNIT_UUID" data-ssp-size="300x250"></div>
```

Use `data-endpoint` on the script tag when the file is self-hosted but bids go to the SSP host.

### iOS — minimal banner

```swift
DKMadsMobileAds.shared.start(with: config)
let banner = DKMadsBannerAdView(adUnitID: "AD_UNIT_UUID", adSize: CGSize(width: 300, height: 250))
banner.rootViewController = self
banner.load()
```

### Android — minimal banner

```kotlin
SSPSDK.initialize(context, config)
val banner = DKMadsBannerAdView(context, adUnitId = "AD_UNIT_UUID")
banner.load()
```

---

## 5. Bid API (shared)

**Endpoint:** `POST /api/public/v1/bid`  
**Header:** `X-Integration-Key: {property integration key}`

**Fill detection:** treat as filled when `winner.adm` or `winner.image_url` is present.  
`winner.id` / `winner.crid` are optional but recommended for reporting.

| `reason` | Meaning |
|----------|---------|
| `won` | Creative returned — render it |
| `no_tiers` | Property waterfall empty — save waterfall in dashboard |
| `no_bids` | No eligible campaign/creative — check status, inventory, format |
| `targeting_mismatch` | Ad unit targeting chips failed — relax rules or pass signals |

Use `"debug": true` in the bid body during QA to receive `log` and `fraud` details.

---

## 6. Targeting & first-party data

- **Campaign targeting** (dashboard): geo, age, gender, interests, audiences — empty fields mean no filter on that dimension.
- **Publisher signals** (SDK): `setTargetingSignals` — see [TARGETING_SIGNALS.md](./TARGETING_SIGNALS.md).
- **FPD:** web `SSP.sendFirstPartyData` / mobile `syncFirstPartyProfile` for audience building.

---

## 7. Metrics & viewability

Event names and auto-instrumentation: [SDK_METRICS_REFERENCE.md](./SDK_METRICS_REFERENCE.md).

- **Banner:** `DKMadsBannerAdView` / `SSP.bind` — IAB viewability (50% / 1s).
- **Interstitial:** `DKMadsInterstitialAd` (iOS/Android) — fullscreen video, image, HTML5; use IAB sizes (320×480), not screen pixels.
- **Video / instream:** iOS `DKMadsVideoAdView` + `DKMadsInstreamAdsLoader`; Android same + `DKMadsContentPlayback` for ExoPlayer pause/resume; web `SSP.bindVideo`.
- **Video (BYO player):** `DKMadsVideoAdController` — attach your ExoPlayer / AVPlayer for quartiles.
- **Native (Android):** `DKMadsNativeAdView` — image / HTML native units.
- **Audio:** web `SSP.bindAudio`; Android `DKMadsAudioAdView` (`audio_url` / `adm`).
- **Diagnostics:** `DKMadsResponseInfo.summary` on all Android drop-in views (and iOS equivalents).

---

## 8. Troubleshooting

| Symptom | Check |
|---------|--------|
| `401` on bid | Integration key, property active |
| `no_tiers` | Waterfall saved for property |
| `no_bids` | Campaign/line item/creative active; inventory targets; format match |
| `targeting_mismatch` | Ad unit targeting chips vs request signals |
| SDK shows no ad but `reason: won` | Render `adm` / `image_url`; ensure `hasFill` logic uses creative not only `id` |
| HTML error from API | Wrong `baseURL` — must be API host, not publisher site origin |

---

## 9. Release checklist

Complete [SDK_INTEGRATION_CHECKLIST.md](./SDK_INTEGRATION_CHECKLIST.md) before production traffic.

Validation scripts (repo):

```bash
bash scripts/sdk-contract-check.sh
bash scripts/validate-platform-alignment.sh
```

---

## Related SDK source

| Path | Contents |
|------|----------|
| `sdk/ios/` | Swift package + sample app |
| `sdk/android/` | Kotlin SDK |
| `sdk/flutter/` | Flutter plugin |
| `sdk/unity/` | Unity bridge |
| `public/sdk/ssp-sdk.js` | Web IIFE bundle |
