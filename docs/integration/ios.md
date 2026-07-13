# iOS SDK integration guide

Integrate banner, interstitial, video, and native ads in native iOS apps with **DKMadsSSPSDK**.

**Hub:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [SDK contract](../SDK_CONTRACT.md) · [Targeting signals](../TARGETING_SIGNALS.md)

## Prerequisites

- Xcode 16+
- iOS 13.0+
- CocoaPods or Swift Package Manager
- DKMads property (iOS), integration key, and ad unit UUID from the dashboard

## Installation

Official SDK repository: **https://github.com/DKMads-Codocs/dkmads-ssp-sdk**

| | |
|---|---|
| **Package** | `DKMadsSSPSDK` |
| |||||**Version** | `0.5.27` |
| **Release tag** | `sdk-0.5.27` |

> **Distribution:** the podspec is **CocoaPods trunk-lintable** and a `pod trunk push` job is wired in CI. Until a trunk release is live, install via the Git/`:tag` source below.

### CocoaPods (Git — recommended)

```ruby
platform :ios, '13.0'
use_frameworks!

pod 'DKMadsSSPSDK',
    :git => 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git',
    :tag => 'sdk-0.5.27',
    :podspec => 'ios/DKMadsSSPSDK.podspec'
```

```bash
pod install
open YourApp.xcworkspace
```

Pin `:tag` to a [release tag](https://github.com/DKMads-Codocs/dkmads-ssp-sdk/tags) (`sdk-<semver>`).

### CocoaPods (local path)

```ruby
pod 'DKMadsSSPSDK', :path => '../dkmads-ssp-sdk/ios'
```

### Swift Package Manager

1. Clone `https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git`.
2. Xcode → **File → Add Package Dependencies → Add Local…**
3. Select the **`ios`** directory.
4. Add product **DKMadsSSPSDK** to your app target.

### Example project

`ios/Sample/` in the SDK repository.

## 1) Start SDK (AppDelegate)

One-time SDK bootstrap (call before loading ads).

```swift
import DKMadsSSPSDK

let config = SSPSDKConfig(integrationKey: "YOUR_INTEGRATION_KEY")
config.baseURL = "https://ssp.dkmads.com"
config.debug = true
DKMadsMobileAds.shared.start(with: config)
```

## 2) Drop-in banner view (recommended)

Drop-in banner view. **Automatically tracks** served + IAB viewable impressions.

**Required before `load()`:** SDK init (§1), `rootViewController`, `delegate`, and a `DKMadsAdRequest` with `placementCode` (server rejects explicit `"placement_code": null`). The SDK defaults `placementCode` → ad unit UUID and `placementContext` → `"banner"` when omitted, but setting them explicitly is recommended.

```swift
// After DKMadsMobileAds.shared.start(with: config) in AppDelegate / scene

let banner = DKMadsBannerAdView(
  adUnitID: "YOUR_AD_UNIT_UUID",
  adSize: CGSize(width: 300, height: 250)
)
banner.rootViewController = self   // Safari click-through on tap
banner.delegate = self
banner.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(banner)
NSLayoutConstraint.activate([
  banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
  banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
  banner.widthAnchor.constraint(equalToConstant: 300),
  banner.heightAnchor.constraint(equalToConstant: 250),
])
view.layoutIfNeeded()

let request = DKMadsAdRequest()
request.placementCode = "YOUR_AD_UNIT_UUID"
request.placementContext = "banner"
request.keyValues = ["test_mode": true]  // optional, SDK-only / QA
banner.load(request)
```

After layout changes, call `banner.updateAdSize(_:)` (Swift) / `updateAdSize:` (ObjC) to update **IAB bid metadata** — not view layout (use Auto Layout constraints for sizing).

**Bid vs render (0.5.17+):** `adSize` / `load(bidSize:)` → IAB tokens for `/v1/bid`. WebView viewport uses **laid-out bounds** (`renderSlotSize`). Optional `load(request, bidSize: CGSize(width: 300, height: 250))` to bid IAB while the view is responsive.

Delegate callbacks:

- `bannerAdViewDidReceiveAd` — hide loading UI
- `bannerAdView(_:didFailToReceiveAdWithError:)` — show error / retry
- `bannerAdViewDidRecordViewableImpression` (50% visible ≥1s)

## 2b) Video ads (your player required)

```swift
let video = DKMadsVideoAdController(adUnitID: "YOUR_VIDEO_AD_UNIT")
video.delegate = self
video.load { result in
  // Set player item from video.loadedAd, then:
  video.attach(player: avPlayer, containerView: playerContainer, skippable: true)
}
```

Emits `video_start`, `video_25`…`video_100`, `video_skip`, `video_viewable`, etc. See `docs/SDK_METRICS_REFERENCE.md`.

## 2c) Interstitial (fullscreen)

Use when the dashboard ad unit format is **interstitial** (Fullscreen & breaks — not Native or banner).

Supports **video**, **image**, **HTML5**, and tag/`adm` creatives from `/v1/bid` (`video_url`, `image_url`, `html5_entry_url`, `adm`).

**Render fork (0.5.22+):** the bid winner carries an explicit **`render_mode`** hint (`image` / `html5` / `video_native` / `video_web` / `native_assets` / `audio`), surfaced as `ad.renderMode`. All drop-in views honor it first and fall back to the legacy `isVideo` / `isHTML5` heuristics when absent. HTML5/`adm` creatives run through the **MRAID 2.0** bridge automatically.

Bid sizes use explicit `adSize`, then sizes from `registerAdUnit`, then **320×480** — not `UIScreen` pixel dimensions (avoids `no_bids` on full-screen device sizes).

```swift
SSPSDK.shared.registerAdUnit(
  code: "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  format: .interstitial,
  sizes: [CGSize(width: 320, height: 480), CGSize(width: 300, height: 600)]
)

let request = DKMadsAdRequest()
request.placementCode = "YOUR_INTERSTITIAL_AD_UNIT_UUID"
request.placementContext = "interstitial"

DKMadsInterstitialAd.load(
  adUnitID: "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  adSize: CGSize(width: 320, height: 480),
  request: request
) { ad, error in
  guard let ad = ad else { return }
  ad.delegate = self
  ad.present(from: self) // top UIViewController — built-in ✕ close stays above creative
}
```

**Interstitial behavior (0.5.12+):**

- Fullscreen HTML/image/video scales to fit the device (`contain`); letterbox areas use **90% opaque black** (`rgba(0,0,0,0.9)`) (0.5.16+).
- Tap anywhere on the creative or embedded links opens the landing page in Safari.
- SDK defaults `placementCode` → ad unit UUID and `placementContext` → `"interstitial"` when omitted.
- Use the top-trailing **✕** to dismiss (video interstitials do not show a separate skip chip).

## 2d) Rewarded (fullscreen with reward callback)

```swift
DKMadsRewardedAd.load(adUnitID: "YOUR_REWARDED_AD_UNIT_UUID") { ad, error in
  guard let ad = ad else { return }
  ad.delegate = self
  ad.present(from: self)
}
```

ObjC: `+[DKMadsRewardedAd loadRewardedWithAdUnitID:request:completion:]` (no optional `CGSize` on `@objc` load).

Delegate callback to grant reward: `rewardedAdDidEarnReward`.

Delegate: `interstitialAdDidReceiveAd`, `interstitialAdDidPresent`, `interstitialAdDidDismiss`, `interstitialAd(_:didFailToReceiveAdWithError:)`.

ObjC: `+[DKMadsInterstitialAd loadInterstitialWithAdUnitID:request:completion:]` then `presentFromRootViewController:`.

## 2e) App open (splash)

Create an ad unit with dashboard format **splash**, then:

```swift
DKMadsAppOpenAd.load(adUnitID: "YOUR_SPLASH_AD_UNIT_UUID") { ad, error in
  guard let ad = ad else { return }
  ad.present(from: self) // on cold start or resume
}
```

## Ad Inspector

```swift
DKMadsMobileAds.shared.presentAdInspector(from: self)
```

Shows the last bid (request id, reason, latency) and troubleshooting hints in a full-screen sheet.

## 3) Manual load API (advanced)

```swift
SSPSDK.shared.loadAd(
  code: "YOUR_AD_UNIT_UUID",
  format: .banner,
  sizes: [CGSize(width: 300, height: 250)]
) { result in
    switch result {
  case .success(let response):
    print(response.responseInfo.summary)
    if response.success, let ad = response.ad {
      // ad.isVideo, ad.isHTML5, ad.creativeUrl, ad.adm, ad.videoUrl
        }
    case .failure(let error):
    print(error.localizedDescription)
    }
}
```

## Consent + user data

The SDK **auto-reads IAB CMP storage** (Google UMP) on init and before each ad request:

- `IABTCF_TCString`, `IABTCF_gdprApplies`
- `IABUSPrivacy_String`
- `IABGPP_GppString`, `IABGPP_SID`
- iOS **ATT** status (0–3); **IDFA** only when ATT authorized and consent allows

Explicit `setConsent` values take precedence when non-blank. Do **not** use `syncFirstPartyProfile` on exchange inventory (server blocks when exchange strict mode is on).

```swift
// Optional after UMP — SDK merges CMP automatically:
SSPSDK.shared.setConsent(ConsentData(
  gdpr: true,
  consentString: tcfFromCmp,
  usPrivacyString: uspFromCmp,
  attStatus: Int(ATTrackingManager.trackingAuthorizationStatus.rawValue)
))

SSPSDK.shared.setTargetingSignals(TargetingSignals(
  devicePid: "device_123",
  userPid: "user_abc",
  gender: "M",
  dateOfBirth: "1998-06-15",
  geoCountry: "MM",
  interests: ["sports", "news"],
  keywords: ["football"]
))

// SSPSDK.shared.syncFirstPartyProfile(appBundle: Bundle.main.bundleIdentifier) { _ in }

SSPSDK.shared.setUserData([
  "device_pid": "device_123",
  "user_pid": "user_abc"
])
```

## Open Measurement (OMID) — optional

`render_mode` and any `omid_verifications` from the bid winner are parsed automatically (`Ad.omidVerifications`), but the IAB Open Measurement SDK is **never bundled**. To enable verified measurement, implement `DKMadsOmidProvider` and register it once; the SDK then drives the full session lifecycle (load, impression, video quartiles, skip, complete) for banner, native, interstitial, and video surfaces:

```swift
// In AppDelegate, after DKMadsMobileAds.shared.start(with:)
DKMadsOmid.provider = MyOmidProvider() // your IAB OM SDK adapter
```

When no provider is registered, OMID is a no-op and first-party viewability still reports. See [OMID & viewability](../OMID_VIEWABILITY.md).

## Curl parity check

```bash
curl -sS -X POST 'https://ssp.dkmads.com/api/public/v1/bid' \
  -H 'Content-Type: application/json' \
  -H 'X-Integration-Key: YOUR_INTEGRATION_KEY' \
  -d '{"ad_unit_id":"YOUR_AD_UNIT_UUID","debug":true,"request":{"sizes":["300x250"],"device_type":"mobile","os":"ios"}}'
```

## Common mistakes

| Mistake | Result |
|---|---|
| Wrong base URL (`api.dkmads.com`) | HTML error / invalid JSON |
| Workspace ID used as ad unit | `ad_unit_not_found` |
| Waterfall not saved | `no_tiers` |
| No matching creative size | `no_bids` |

## Sample app

See `ios/Sample/README.md` in the SDK repository.

## Kit layout

See `ios/README.md` in [dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk), [SDK_CONTRACT.md](../SDK_CONTRACT.md), [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md), [SDK_METRICS_REFERENCE.md](../SDK_METRICS_REFERENCE.md).
