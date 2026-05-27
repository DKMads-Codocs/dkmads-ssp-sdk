# SDK implementation guide

The central reference for integrating DKMads across **web, iOS, Android, Flutter, and Unity**.

**Audience:** publisher engineering teams  
**Outcome:** a verified property, successful bid, rendered creative, and compliant telemetry  
**Fast path:** [60-minute quickstart](./integration/QUICKSTART.md) · **In dashboard:** Developer → SDK guide

---

## 1. Prerequisites

Collect these from the DKMads dashboard before writing integration code:

| Item | Where to find it |
|------|------------------|
| **Property** (web, iOS, or Android) | Inventory → Properties — status must be active |
| **Integration key** | Property settings |
| **Ad unit** (UUID, format, size) | Inventory → Ad units |
| **Waterfall** | Demand → Waterfall — click **Save** after edits |
| **Campaign + creative** | Matching ad unit format and size, approved |

### API endpoints

| Environment | Base URL |
|-------------|----------|
| Production | `https://ssp.dkmads.com` |
| Custom deployment | Your host serving `/api/public/v1/*` |

All platforms use:

- `POST /api/public/v1/bid` — auction (header `X-Integration-Key`)
- `POST /api/public/v1/events` — telemetry batch

Web additionally loads `https://ssp.dkmads.com/api/public/sp.js`.

---

## 2. Choose your platform

| Platform | Delivery | Guide |
|----------|----------|--------|
| Web | Hosted script | [Web integration](./integration/web.md) |
| iOS | `DKMadsSSPSDK` (SPM / CocoaPods) | [iOS integration](./integration/ios.md) |
| Android | `com.dkmads.ssp:ssp-android` | [Android integration](./integration/android.md) |
| Flutter | `dkmads_ssp` plugin + native SDKs | [Flutter integration](./integration/flutter.md) |
| Unity | `com.dkmads.ssp` UPM + native SDKs | [Unity integration](./integration/unity.md) |

**Mobile SDK releases:** [github.com/DKMads-Codocs/dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk) — use the version shown in your dashboard SDK guide (tags `sdk-<semver>`).

---

## 3. Standard integration flow

```text
1. Initialize the SDK once (app launch or page load)
2. Set consent when GDPR, US privacy, or ATT applies
3. Set targeting signals (optional)
4. Request an ad or use a banner/video component
5. Render winner.adm and/or winner.image_url
6. Confirm impression and engagement events in Reports
```

Full API details: [SDK contract](./SDK_CONTRACT.md).

### Minimal examples

**Web**

```html
<script>window.ssp = window.ssp || [];</script>
<script async src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_INTEGRATION_KEY"></script>
<div data-ssp-ad-unit="AD_UNIT_UUID" data-ssp-size="300x250"></div>
```

**iOS**

```swift
DKMadsMobileAds.shared.start(with: config)
let banner = DKMadsBannerAdView(adUnitID: "AD_UNIT_UUID", adSize: CGSize(width: 300, height: 250))
banner.rootViewController = self
banner.load()
```

**Android**

```kotlin
SSPSDK.initialize(context, config)
val banner = DKMadsBannerAdView(context, adUnitId = "AD_UNIT_UUID")
banner.load()
```

---

## 4. Bid API essentials

**Fill rule:** treat the response as filled when `winner.adm` or `winner.image_url` is present (do not rely on `winner.id` alone).

| `reason` | Meaning | Action |
|----------|---------|--------|
| `won` | Creative available | Render `adm` or image URL |
| `no_tiers` | No waterfall configured | Save waterfall for the property |
| `no_bids` | No eligible demand | Check campaign, creative, format, targeting |
| `targeting_mismatch` | Ad unit rules not met | Adjust signals or ad unit targeting |
| `consent_blocked` | Privacy gate failed | Fix CMP / ATT / USP (see consent docs) |

During QA, include `"debug": true` in the bid body for diagnostic logs.

---

## 5. Targeting and audiences

| Layer | Where | Purpose |
|-------|--------|---------|
| Campaign targeting | Dashboard → Campaigns | Geo, demographics, interests, audiences |
| Publisher signals | SDK `setTargetingSignals` | Per-request context — [Targeting signals](./TARGETING_SIGNALS.md) |
| First-party profiles | SDK FPD APIs | House campaigns only; blocked on exchange strict mode |

---

## 6. Measurement

Use platform components that auto-fire IAB-aligned events where possible:

| Format | Web | iOS / Android |
|--------|-----|----------------|
| Banner | `SSP.bind` | `DKMadsBannerAdView` |
| Interstitial | `SSP.displayInterstitial` | `DKMadsInterstitialAd` |
| Video | `SSP.bindVideo` | `DKMadsVideoAdController`, instream loader |
| Audio | `SSP.bindAudio` | `DKMadsAudioAdView` (Android) |

Event catalog: [SDK metrics reference](./SDK_METRICS_REFERENCE.md).

---

## 7. Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| HTTP 401 on bid | Invalid integration key or inactive property |
| `no_tiers` | Waterfall not saved |
| `no_bids` | Inactive campaign/creative or format mismatch |
| `targeting_mismatch` | Ad unit chips vs bid signals |
| Ad blank but `reason: won` | Not rendering `adm` / `image_url` |
| API returns HTML | Wrong `baseUrl` — must be SSP API host |

---

## 8. Launch readiness

Complete the [SDK integration checklist](./SDK_INTEGRATION_CHECKLIST.md) before directing production traffic.

---

## 9. Google Exchange (optional)

If your workspace supports Google demand, complete consent and transparency before pilot traffic:

| Guide | Focus |
|-------|--------|
| [SDK Google policy checklist](./SDK_GOOGLE_POLICY_CHECKLIST.md) | Per-platform consent |
| [Regional consent matrix](./REGIONAL_CONSENT_MATRIX.md) | Dashboard privacy settings |
| [How Google Exchange works](./GOOGLE_EXCHANGE_ARCHITECTURE.md) | Model and responsibilities |
| [Pilot rollout](./GOOGLE_PILOT_ROLLOUT.md) | Testing → live in Privacy settings |

Configure **Privacy & Compliance** (exchange strict mode, supply chain, Google rollout).
