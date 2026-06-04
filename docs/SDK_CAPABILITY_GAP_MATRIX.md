# SDK capability gap matrix

Last updated: 2026-05-27  
**Version:** unified **`sdk/VERSION`** — web, iOS, Android, Flutter, Unity (currently **0.5.1**)

Compares **DKMads SSP SDKs** to typical **top-tier publisher mobile SDKs** (large network SDKs and mediation hubs). This is a capability map, not a competitor feature list.

**Related:** [Platform parity](./PLATFORM_ALIGNMENT.md) · [Publisher API map](./SDK_PUBLISHER_API_MAP.md) · [SDK contract](./SDK_CONTRACT.md)

---

## At parity (native iOS / Android)

| Capability | DKMads |
|------------|--------|
| Initialize + integration key | `DKMadsMobileAds.start` / `SSPSDK.initialize` |
| Banner drop-in + viewability | `DKMadsBannerAdView` |
| Interstitial / rewarded / app open | Dedicated classes + fullscreen callbacks |
| Native load + assets | `DKMadsNativeAd` + `DKMadsNativeAdAssets` (or `DKMadsNativeAdView`) |
| Adaptive banner sizes | `DKMadsAdSize` helpers |
| Server refresh interval | `refresh_interval_sec` on bid |
| Consent gate | `canRequestAds()`, `requireConsentBeforeAds` |
| Targeting + FPD | `setTargetingSignals`, `syncFirstPartyProfile` |
| Fill diagnostics | `DKMadsResponseInfo`, Ad Inspector, `debug: true` |
| Fullscreen cache expiry | 4h TTL on show (`AD_EXPIRED` / `ad_expired`) |
| Video / instream | `DKMadsVideoAdController`, `DKMadsInstreamAdsLoader` |
| Audio | `DKMadsAudioAdView` (Android), audio events |

---

## Remaining gaps (prioritized)

### P0 — Distribution & onboarding

| Gap | Status | Action |
|-----|--------|--------|
| Android one-line Maven | **Documented** | GitHub Packages install in [Android guide](./integration/android.md); CI publishes on release when `SDK_PUBLISH_TOKEN` is set |
| Guaranteed test fill unit | Partial | `useTestAds` + dashboard creatives; document QA checklist in [SDK_TEST_MODE](./SDK_TEST_MODE.md) |

### P1 — By design (SSP model)

| Gap | Notes |
|-----|--------|
| Third-party mediation mesh | Not planned — direct auction + transparent `dsp`/`price` |
| Bundled CMP UI | Publisher supplies CMP; SDK reads TCF/GPP |

### P1 — Product depth

| Gap | DKMads | Typical leader |
|-----|--------|----------------|
| OMID in-app SDK | MRC events; roadmap in [OMID_VIEWABILITY](./OMID_VIEWABILITY.md) | Full OMID session |
| VAST / IMA player kit | MP4/WebView + lifecycle events | Official player adapters |
| SKAN helper APIs | Policy docs + ATT | Conversion value helpers |
| Unified `preload(token)` | Per-format `load` | Single preload API |

### P2 — Cross-platform

| Gap | Status |
|-----|--------|
| Unity banner widget | JSON `LoadAd` + sample; no UGUI prefab |
| React Native | [sdk/react-native/README.md](../sdk/react-native/README.md) stub — use native modules pattern |
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

---

## Backend / dashboard alignment

- Ad unit formats in dashboard match bid `format` strings (`splash`, `rewarded`, …).
- `resolveEffectiveAdUnitFormat` + house auction treat **splash** like fullscreen for IAB sizes.
- Ad unit wizard includes splash with SDK hint `DKMadsAppOpenAd`.

---

## Historical doc

Older audit: [SDK_V1_GAP_ANALYSIS.md](./SDK_V1_GAP_ANALYSIS.md) (archived context — many items are now closed in 0.5.0).
