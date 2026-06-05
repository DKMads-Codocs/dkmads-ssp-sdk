# DKMads SSP iOS SDK (v0.5.9)

Production-oriented iOS SDK kit for DKMads SSP integration.

## Kit structure

```text
sdk/ios/
  Package.swift                 # Swift Package Manager
  DKMadsSSPSDK.podspec            # CocoaPods
  Sources/DKMadsSSPSDK/
    Core/                         # SSPSDK, DKMadsMobileAds, config
    Models/                       # Ad, AdResponse, ResponseInfo
    Network/                      # APIClient, PublicAPIPaths
    UI/                           # Banner, VideoAdView, Instream loader, VideoAdController
    Models/                       # TargetingSignals, AdFormat, ConsentData
    Telemetry/                    # TelemetryManager
  Sample/                         # Example app (CocoaPods)
```

## Install (CocoaPods)

```ruby
pod 'DKMadsSSPSDK', :path => '../sdk/ios'
```

Run `pod install` from your app folder.

## Install (Swift Package Manager)

In Xcode: **File → Add Package Dependencies → Add Local** and select `sdk/ios`.

## Quick integration (recommended)

```swift
import DKMadsSSPSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let config = SSPSDKConfig(integrationKey: "YOUR_INTEGRATION_KEY")
        config.baseURL = "https://ssp.dkmads.com"
        config.debug = true
        DKMadsMobileAds.shared.start(with: config)
        return true
    }
}
```

```swift
let bannerView = DKMadsBannerAdView(adUnitID: "YOUR_AD_UNIT_UUID",
                                    adSize: CGSize(width: 300, height: 250))
bannerView.rootViewController = self
bannerView.delegate = self
view.addSubview(bannerView)
bannerView.load()
```

## Targeting & audiences

```swift
SSPSDK.shared.setTargetingSignals(TargetingSignals(
  devicePid: "device_123",
  userPid: "user_abc",
  gender: "M",
  dateOfBirth: "1998-06-15",
  geoCountry: "US",
  interests: ["sports", "news"],
  keywords: ["football"]
))
// Optional: sync profile for dashboard Audiences rules
SSPSDK.shared.syncFirstPartyProfile(appBundle: Bundle.main.bundleIdentifier) { _ in }
```

See [docs/TARGETING_SIGNALS.md](../../docs/TARGETING_SIGNALS.md).

## Video / instream (drop-in)

```swift
// Option A — DKMads view class (recommended)
let videoView = DKMadsVideoAdView(adUnitID: videoUnitUUID, frame: adFrame)
videoView.delegate = self
parentView.addSubview(videoView)
let req = DKMadsAdRequest()
req.placementContext = "pre_roll"
videoView.load(req)

// Option B — IMA-style coordinator (pause content → ad → resume)
let loader = DKMadsInstreamAdsLoader(contentPlayer: contentPlayer, adContainer: adOverlay)
loader.delegate = self
loader.pauseContentAutomatically = true
loader.resumeContentAfterAd = true
loader.requestAds(adUnitID: videoUnitUUID, contentPosition: "pre_roll")

// Option C — bring your own AVPlayer (telemetry + play helper)
let controller = DKMadsVideoAdController(adUnitID: videoUnitUUID)
controller.load { result in
  if case .success = result, let ad = controller.loadedAd {
    controller.play(in: contentPlayer, containerView: adOverlay)
  }
}
```

`Ad` exposes `videoUrl`, `preferredPlaybackURL`, `deliveryType`, `isVideo`, and `preferredRenderer` (`.nativeMP4` vs `.webMarkup`).

All `loadAd` completions run on the **main thread**. `loadedAd` is set before success callbacks.

Errors use `DKMadsAdError` (`noFill`, `missingVideoURL`, `playbackFailed`, etc.).

Set `SSPSDKConfig.useTestAds = true` for verbose bid logging (`debug: true` on requests). Use dashboard test creatives / known MP4 ad units for predictable fills.

**WebView video:** `videoAdViewDidComplete` fires via HTML5 `ended` hooks. Quartile telemetry (`video_25` … `video_100`) is emitted on the **native MP4** path only; WebView/HTML5 ads report start + complete.

**Skip:** `DKMadsVideoAdView.isSkippable` and `skipOffsetSeconds` (default 5s).

**Fullscreen interstitial:** `DKMadsInterstitialAd.load(...)` then `present(from:)` — video, image, HTML5, and `adm` tag creatives (uses `Ad.videoUrl`, `isHTML5`, `creativeUrl`). ObjC: `loadInterstitialWithAdUnitID:request:completion:` (avoid `load`, conflicts with `+load`).

**Instream analytics:** read `loader.loadedAd` and `loader.responseInfo` in `instreamAdsLoaderDidStartAd` — one bid per `requestAds`, no separate `loadAd` call.

See `docs/SDK_METRICS_REFERENCE.md` for quartile / viewability events.

## Required Info.plist

- `NSAppTransportSecurity` — allow HTTPS to `ssp.dkmads.com` (default ATS is fine for HTTPS).
- Optional: `SKAdNetworkItems` for attribution.
- Optional: `NSUserTrackingUsageDescription` if using ATT.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `notInitialized` | Call `DKMadsMobileAds.shared.start(...)` in `AppDelegate` |
| HTML response error | Use `https://ssp.dkmads.com` as `baseURL` |
| `no_tiers` | Save property waterfall in dashboard |
| Blank banner with `won` | Ensure `adm` renders in `DKMadsBannerAdView` (built-in WebView) |

See also: `docs/integration/ios.md`, `docs/SDK_CONTRACT.md`.
