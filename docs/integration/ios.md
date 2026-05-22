# iOS SDK Quickstart

Integrate DKMads SSP in a native iOS app using **DKMadsSSPSDK** (v0.4.2).

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
| **Version** | `0.4.2` |
| **Release tag** | `sdk-0.4.2` |

### CocoaPods (Git — recommended)

```ruby
platform :ios, '13.0'
use_frameworks!

pod 'DKMadsSSPSDK',
    :git => 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git',
    :tag => 'sdk-0.4.2',
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

```swift
let banner = DKMadsBannerAdView(
  adUnitID: "YOUR_AD_UNIT_UUID",
  adSize: CGSize(width: 300, height: 250)
)
banner.rootViewController = self
banner.delegate = self
view.addSubview(banner)
banner.load()
```

Delegate callbacks:

- `bannerAdViewDidReceiveAd`
- `bannerAdViewDidRecordViewableImpression` (50% visible ≥1s)
- `bannerAdView(_:didFailToReceiveAdWithError:)`

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

Bid sizes use explicit `adSize`, then sizes from `registerAdUnit`, then **320×480** — not `UIScreen` pixel dimensions (avoids `no_bids` on full-screen device sizes).

```swift
SSPSDK.shared.registerAdUnit(
  code: "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  format: .interstitial,
  sizes: [CGSize(width: 320, height: 480), CGSize(width: 300, height: 600)]
)

DKMadsInterstitialAd.load(
  adUnitID: "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  adSize: CGSize(width: 320, height: 480)
) { ad, error in
  guard let ad = ad else { return }
  ad.delegate = self
  ad.present(from: self) // top UIViewController
}
```

Delegate: `interstitialAdDidReceiveAd`, `interstitialAdDidPresent`, `interstitialAdDidDismiss`, `interstitialAd(_:didFailToReceiveAdWithError:)`.

ObjC: `+[DKMadsInterstitialAd loadInterstitialWithAdUnitID:request:completion:]` then `presentFromRootViewController:`.

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

```swift
SSPSDK.shared.setConsent(ConsentData(gdpr: false, ccpa: false))
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
