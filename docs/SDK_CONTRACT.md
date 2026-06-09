# SDK contract (v0.5.x)

Canonical **request, response, and lifecycle** contract for web, iOS, Android, Flutter, and Unity integrations.

All platforms share one semver (`sdk/VERSION` in the monorepo, currently **0.5.15**).

**Use with:** [Implementation guide](./SDK_IMPLEMENTATION_GUIDE.md) · platform integration guides

## Design principles

1. **Initialize once at app launch** before any ad request.
2. **Set consent/user data** before first ad request when required.
3. **Use integration key + ad unit ID** for all ad calls.
4. **Use one base URL**: `https://ssp.dkmads.com`.
5. **Return structured fill diagnostics** (`reason`, `request_id`, `dsp`, `price`).

## Required credentials

| Field | Required | Notes |
|---|---|---|
| `integrationKey` | Yes | Property integration key from dashboard |
| `adUnitId` | Yes | UUID from Ad Units page |
| `baseUrl` | Recommended | Default is `https://ssp.dkmads.com` |

Do **not** use workspace ID as ad unit ID.

## Canonical lifecycle

```text
initialize(config)
  -> setConsent(optional)
  -> setTargetingSignals(optional)   // recommended: demographics, geo, interests
  -> setUserData(optional)          // legacy flat map; merged with targeting
  -> syncFirstPartyProfile(optional) // mobile FPD for Audiences
  -> loadAd(request) OR BannerAdView.load()
  -> render winner (adm or image URL)
  -> auto metrics (banner view / video attach) + trackUserEvent
```

Full targeting schema: [TARGETING_SIGNALS.md](TARGETING_SIGNALS.md).

## Unified method map

| Capability | iOS | Android | Flutter | Unity | Web |
|---|---|---|---|---|
| Initialize | `DKMadsMobileAds.start` / `SSPSDK.initialize` | `SSPSDK.initialize` | `DkmadsSsp.initialize` | `DKMadsSdk.Initialize` | `SSP.init` |
| Consent | `setConsent(_:)` | `setConsent(...)` | `setConsent(...)` | `SetConsent(DKMadsConsent)` | `SSP.setConsent` |
| Targeting signals | `setTargetingSignals(_:)` | `setTargetingSignals(...)` | `setTargetingSignals(map)` | native `SetUserData` | `SSP.setTargetingSignals` |
| User data | `setUserData(_:)` | `setUserData(map)` | `setUserData(map)` | `SetUserData(json)` | `SSP.setUser` |
| FPD profile sync | `syncFirstPartyProfile` | `syncFirstPartyProfile` | `syncFirstPartyProfile` | — | `sendFirstPartyData` / `collectFirstParty` |
| Banner UI + metrics | `DKMadsBannerAdView` | `DKMadsBannerAdView` | `DkmadsBannerAd` widget | — | `SSP.bind` |
| Interstitial UI | `DKMadsInterstitialAd` | `DKMadsInterstitialAd` | `loadInterstitial` + `showInterstitial` | `LoadInterstitial` + `ShowInterstitial` | `SSP.displayInterstitial` |
| App open (splash) | `DKMadsAppOpenAd` | `DKMadsAppOpenAd` | `loadAppOpen` + `showAppOpen` | `LoadAppOpen` + `ShowAppOpen` | `SSP.displaySplash` |
| Ad Inspector | `DKMadsMobileAds.presentAdInspector` | `DKMadsAdInspector` | `presentAdInspector` | `PresentAdInspector` | `SSP.lastBidDiagnostics` |
| Consent gate | `canRequestAds()` | `canRequestAds()` | via native | via native | `SSP.canRequestAds()` |
| Native assets | `DKMadsNativeAdAssets` | `DKMadsNativeAdAssets` | `loadNative` fields | `LoadNative` JSON | `winner.native_assets` / auto native card |
| Video metrics | `DKMadsVideoAdController` | `DKMadsVideoAdView` | `trackVideoLifecycle` | `EmitVideoEvent` | `SSP.bindVideo` |
| Audio metrics | `DKMadsAudioAdView` / events | `DKMadsAudioAdView` | manual events | manual events | `SSP.bindAudio` |
| Load ad (raw) | `loadAd(...)` | `loadAd(...)` | `loadBanner(...)` | `LoadAd` / `LoadAdWithFormat` | `SSP.requestAd` |
| App events | `trackUserEvent(...)` | `trackUserEvent(...)` | `trackUserEvent(...)` | `TrackUserEvent` | `SSP.track` |

## Standard request object

```json
{
  "ad_unit_id": "uuid",
  "placement_code": "optional",
  "placement_context": "optional",
  "key_values": {},
  "request": {
    "id": "uuid",
    "sizes": ["300x250"],
    "device_type": "mobile",
    "os": "ios|android"
  },
  "signals": {
    "user_pid": "optional",
    "device_pid": "optional",
    "gender": "M",
    "date_of_birth": "1998-06-15",
    "yob": 1998,
    "geo_country": "US",
    "geo_region": "optional",
    "connection_type": "wifi",
    "interests": { "tags": ["sports"], "keywords": ["football"] },
    "keywords": ["football"],
    "segments": ["premium"],
    "gdpr": false,
    "us_privacy": "1---",
    "tcf_string": "optional"
  },
  "debug": true
}
```

## Standard success response

```json
{
  "ad_unit_id": "uuid",
  "request_id": "uuid",
  "reason": "won",
  "winner": {
    "dsp": "house_ads",
    "price": 2.0,
    "id": "creative-uuid",
    "crid": "creative-uuid",
    "cid": "campaign-uuid",
    "lid": "line-item-uuid",
    "adm": "<html>...</html>",
    "image_url": "https://cdn.example.com/banner.png",
    "click_url": "https://example.com/click",
    "w": 300,
    "h": 250,
    "meta": {}
  }
}
```

`id` / `crid` may be omitted on older API builds; mobile SDKs treat fill as **`adm` or `image_url` present**, not `id` required.

## Standard no-fill reasons

| `reason` | Meaning | Developer action |
|---|---|---|
| `won` | Ad served successfully | Render `adm` or image URL |
| `no_tiers` | No active waterfall tiers for property | Save property waterfall in dashboard |
| `no_bids` | Tiers ran, no eligible bid | Check campaign targeting/creative/size |
| `targeting_mismatch` | Ad unit inventory rules failed | Relax ad unit targeting or pass matching signals |
| `invalid_key` | Bad integration key | Fix key/property status |
| `ad_unit_not_found` | Wrong ad unit ID | Use Ad Units UUID |
| `network_error` | Transport failure | Check network/base URL |

## Rendering contract

- If `winner.adm` is present, render in `WKWebView` (iOS) or WebView (Android).
- If only `winner.image_url` is available, render image directly (web: `<img>`, mobile: image view).
- Use `winner.click_url` for click-through when present.
- Treat fill as **renderable creative** (`adm` or `image_url`), not “non-empty `id`”.
- `success=true` with empty `adm` and empty `image_url` is no-fill.

## Public REST endpoints (publisher)

| Endpoint | Purpose |
|----------|---------|
| `POST /api/public/v1/bid` | Ad auction |
| `POST /api/public/v1/events` | Telemetry batch |
| `POST /api/public/v1/fpd/web` | Web first-party profile |
| `POST /api/public/v1/fpd/mobile` | Mobile first-party profile |

## Minimum copy-paste integration (60 minutes)

### iOS

```swift
let cfg = SSPSDKConfig(integrationKey: "YOUR_INTEGRATION_KEY")
cfg.baseURL = "https://ssp.dkmads.com"
cfg.debug = true
DKMadsMobileAds.shared.start(with: cfg)

SSPSDK.shared.setTargetingSignals(TargetingSignals(
  devicePid: "device_123",
  userPid: "user_abc",
  gender: "M",
  dateOfBirth: "1998-06-15",
  geoCountry: "US",
  interests: ["sports"]
))

// Recommended: auto viewability
let banner = DKMadsBannerAdView(adUnitID: "YOUR_AD_UNIT_UUID", adSize: CGSize(width: 300, height: 250))
banner.load()

// Or raw load:
SSPSDK.shared.loadAd(
  code: "YOUR_AD_UNIT_UUID",
  format: .banner,
  sizes: [CGSize(width: 300, height: 250)]
) { result in
  switch result {
  case .success(let response) where response.success, let ad = response.ad:
    print("fill", ad?.id ?? "", ad?.adm?.prefix(20) ?? "")
  default:
    print("no fill")
  }
}
```

### Android (Kotlin)

```kotlin
val cfg = Config(
  integrationKey = "YOUR_INTEGRATION_KEY",
  baseUrl = "https://ssp.dkmads.com",
  debug = true
)
SSPSDK.initialize(context, cfg)
SSPSDK.setTargetingSignals(
  TargetingSignals(devicePid = "device_123", userPid = "user_abc", geoCountry = "US", interests = listOf("sports"))
)

lifecycleScope.launch {
  val result = SSPSDK.loadAd(
    context = this,
    adUnitCode = "YOUR_AD_UNIT_UUID",
    format = AdFormat.BANNER,
    sizes = listOf(300 to 250)
  )
  result.onSuccess { ad ->
    if (ad.id.isBlank()) println("no fill reason=${ad.reason}") else println("fill ${ad.id}")
  }
}
```

### Flutter

```dart
await DkmadsSsp.initialize(
  integrationKey: 'YOUR_INTEGRATION_KEY',
  baseUrl: 'https://ssp.dkmads.com',
  debug: true,
);
await DkmadsSsp.setTargetingSignals({
  'device_pid': 'device_123',
  'user_pid': 'user_abc',
  'gender': 'M',
  'geo_country': 'US',
  'interests': ['sports'],
});
final result = await DkmadsSsp.loadBanner(
  adUnitId: 'YOUR_AD_UNIT_UUID',
  width: 300,
  height: 250,
);
```

## Versioning policy

- `0.3.x`: additive API only.
- Breaking API changes require `1.0.0`.
