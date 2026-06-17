# SDK capability gap matrix

Last updated: 2026-06-17  
**Version:** unified **`sdk/VERSION`** — web, iOS, Android, Flutter, Unity, React Native (currently **0.5.22**)

Compares **DKMads SSP SDKs** to typical **top-tier publisher mobile SDKs** (large network SDKs and mediation hubs). This is a capability map, not a competitor feature list.

**Related:** [Platform parity](./PLATFORM_ALIGNMENT.md) · [Publisher API map](./SDK_PUBLISHER_API_MAP.md) · [SDK contract](./SDK_CONTRACT.md)

---

## At parity (native iOS / Android)

| Capability | DKMads |
|------------|--------|
| Initialize + integration key | `DKMadsMobileAds.start` / `SSPSDK.initialize` |
| Banner drop-in + viewability | `DKMadsBannerAdView` |
| Interstitial / rewarded / app open | Dedicated classes + fullscreen callbacks; responsive fit + click-through (0.5.12+); 90% letterbox chrome (0.5.14) |
| Native load + assets | `DKMadsNativeAd` + `DKMadsNativeAdAssets` (or `DKMadsNativeAdView`) |
| Adaptive banner sizes | `DKMadsAdSize` helpers |
| Server refresh interval | `refresh_interval_sec` on bid |
| Consent gate | `canRequestAds()`, `requireConsentBeforeAds` |
| Targeting + FPD | `setTargetingSignals`, `syncFirstPartyProfile` |
| Fill diagnostics | `DKMadsResponseInfo`, Ad Inspector, `debug: true` |
| Fullscreen cache expiry | 4h TTL on show (`AD_EXPIRED` / `ad_expired`) |
| Video / instream | `DKMadsVideoAdView` (ExoPlayer MP4+HLS on Android, AVPlayer on iOS), `DKMadsVideoAdController`, `DKMadsInstreamAdsLoader` |
| Audio | `DKMadsAudioAdView` (Android), audio events |
| Server render hint | `render_mode` on bid winner → `ad.renderMode` (explicit render fork) (0.5.22) |
| MRAID 2.0 | WebView bridge for banner / interstitial / native HTML creatives (0.5.22) |
| OMID measurement | Adapter seam (`DKMadsOmidProvider`) — host plugs in IAB OM SDK; SDK drives session lifecycle (0.5.22) |

---

## Remaining gaps (prioritized)

### P0 — Distribution & onboarding

| Gap | Status | Action |
|-----|--------|--------|
| Android one-line Maven | **Documented** | GitHub Packages install in [Android guide](./integration/android.md); **Maven Central** publish wired in CI (gated on Sonatype OSSRH creds) |
| iOS CocoaPods trunk | **Wired** | Podspec is trunk-lintable; `pod trunk push` job in CI |
| Guaranteed test fill unit | Partial | `useTestAds` + dashboard creatives; document QA checklist in [SDK_TEST_MODE](./SDK_TEST_MODE.md) |

### P1 — By design (SSP model)

| Gap | Notes |
|-----|--------|
| Third-party mediation mesh | Not planned — direct auction + transparent `dsp`/`price` |
| Bundled CMP UI | Publisher supplies CMP; SDK reads TCF/GPP |

### P1 — Product depth

| Gap | DKMads | Typical leader |
|-----|--------|----------------|
| OMID in-app SDK | **Adapter seam shipped** (0.5.22) — host plugs in IAB OM SDK; see [OMID_VIEWABILITY](./OMID_VIEWABILITY.md) | OM SDK bundled in-box |
| VAST / IMA player kit | MP4/WebView + lifecycle events | Official player adapters |
| SKAN helper APIs | Policy docs + ATT | Conversion value helpers |
| Unified `preload(token)` | Per-format `load` | Single preload API |

### P2 — Cross-platform

| Gap | Status |
|-----|--------|
| Unity banner widget | JSON `LoadAd` + sample; no UGUI prefab |
| React Native | **Bridge shipped** (0.5.22) — `@dkmads/react-native-ssp` banner + interstitial; see [React Native guide](./integration/react-native.md) |
| Flutter native assets | **Closed** — `loadNative` + `DkmadsAdResult` headline/body/cta fields |

---

## Platform matrix (summary)

| Format | iOS / Android | Flutter | Unity | Web |
|--------|---------------|---------|-------|-----|
| Banner | View | `DkmadsBannerAd` | JSON load | `SSP.bind` |
| Interstitial | Class | load + show | load + show | API |
| Rewarded | Class | load + show | load + show | bindVideo |
| App open | `DKMadsAppOpenAd` | load + show | load + show | `SSP.displaySplash` |
| Native | `DKMadsNativeAd` | `loadNative` | `LoadNative` | `SSP.bind` + `native_assets` |
| Inspector | Full screen | `presentAdInspector` | `PresentAdInspector` | `SSP.lastBidDiagnostics` |

> **React Native** (`@dkmads/react-native-ssp`) covers **banner** + **interstitial** as a thin bridge over the native SDKs; other formats fall back to direct native integration.

---

## Backend / dashboard alignment

- Ad unit formats in dashboard match bid `format` strings (`splash`, `rewarded`, …).
- `resolveEffectiveAdUnitFormat` + house auction treat **splash** like fullscreen for IAB sizes.
- Ad unit wizard includes splash with SDK hint `DKMadsAppOpenAd`.

---

## Historical doc

Older audit: [SDK_V1_GAP_ANALYSIS.md](./SDK_V1_GAP_ANALYSIS.md) (archived context — many items are now closed in 0.5.0).
