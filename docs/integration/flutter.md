# Flutter SDK integration guide

The **dkmads_ssp** plugin bridges Flutter to native iOS and Android SDKs for banners, interstitials, and video events.

**Hub:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [iOS](./ios.md) · [Android](./android.md)

## Prerequisites

- Flutter 3.22+, Dart 3.3+
- Native SDKs installed for each target you ship ([iOS](./ios.md), [Android](./android.md))
- DKMads property, integration key, and ad unit UUID

## Installation

Flutter integration requires three components:

1. **Flutter plugin** — `dkmads_ssp` (Dart API)
2. **iOS library** — `DKMadsSSPSDK`
3. **Android library** — `com.dkmads.ssp:ssp-android`

For web properties, use the [Web SDK](./web.md) (hosted script); there is no Flutter web package.

### 1. Flutter plugin

**Local path** (if you vendor the SDK repo alongside your app):

```yaml
# pubspec.yaml
dependencies:
  dkmads_ssp:
    path: ../dkmads-ssp-sdk/flutter
```

**Git dependency** (separate app repository):

```yaml
dependencies:
  dkmads_ssp:
    git:
      url: https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git
      path: flutter
      ref: sdk-0.5.3   # release tag (sdk-<semver>)
```

```bash
flutter pub get
```

### 2) Install native iOS SDK

In `ios/Podfile` (see [iOS install](./ios.md)):

```ruby
pod 'DKMadsSSPSDK',
    :git => 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git',
    :tag => 'sdk-0.5.3',
    :podspec => 'ios/DKMadsSSPSDK.podspec'
```

Then `cd ios && pod install`.

### 3. Android native SDK

Add `com.dkmads.ssp:ssp-android:0.5.3` per [Android Installation](./android.md).

### Example app

`sdk/flutter/example/`

## Current capability

- Initialize native SDK (`integrationKey`, optional `propertyId/propertyCode`, `baseUrl`, `debug`)
- Set consent / user data
- **`setTargetingSignals`** — structured demographics, geo, interests (native bridge)
- **`syncFirstPartyProfile`** — optional FPD for Audiences
- **`registerAdUnit`** — IAB size tokens for interstitial/banner (native `SSPSDK.registerAdUnit`)
- **`loadBanner`** — native bid + creative payload (`adm`, `videoUrl`, `isVideo`, …)
- **`DkmadsBannerAd`** — embedded banner PlatformView (auto load + viewability)
- **`loadInterstitial`** + **`showInterstitial`** — native fullscreen UI
- **`loadAppOpen`** + **`showAppOpen`** — splash / app open (dashboard format **splash**)
- **`presentAdInspector`** — last bid diagnostics screen
- **`loadNative`** — native format; `DkmadsAdResult` includes `headline`, `body`, `callToAction`, `iconUrl`
- **`loadRewarded`** + **`showRewarded`** — rewarded fullscreen + `rewardedEvent` callbacks
- **`DkmadsInstreamAd`** — instream PlatformView (Android/iOS)
- Track/emit video lifecycle telemetry

> Example app: `sdk/flutter/example/` (initialize, banner widget, interstitial, inspector).

## Quickstart

```dart
await DkmadsSsp.initialize(
  integrationKey: 'YOUR_INTEGRATION_KEY',
  baseUrl: 'https://ssp.dkmads.com',
  debug: true,
);

await DkmadsSsp.registerAdUnit(
  adUnitId: 'INTERSTITIAL_UUID',
  format: 'interstitial',
  sizes: [
    [320, 480],
    [300, 600],
  ],
);
```

### Embedded banner (recommended)

```dart
const DkmadsBannerAd(
  adUnitId: 'BANNER_UUID',
  width: 300,
  height: 250,
)
```

### Banner (JSON load)

```dart
final banner = await DkmadsSsp.loadBanner(
  adUnitId: 'BANNER_UUID',
  width: 300,
  height: 250,
);
if (banner.hasFill) {
  // banner.adm, banner.creativeUrl, banner.videoUrl, banner.isVideo
}
```

### Interstitial (recommended)

Dashboard ad unit format must be **interstitial**. Uses IAB sizes (320×480 default), not screen pixels.

```dart
final fill = await DkmadsSsp.loadInterstitial(
  adUnitId: 'INTERSTITIAL_UUID',
  width: 320,
  height: 480,
);
if (fill.hasFill) {
  await DkmadsSsp.showInterstitial(adUnitId: 'INTERSTITIAL_UUID');
}
```

### App open (splash)

```dart
final splash = await DkmadsSsp.loadAppOpen(adUnitId: 'SPLASH_UUID');
if (splash.hasFill) {
  await DkmadsSsp.showAppOpen(adUnitId: 'SPLASH_UUID');
}
```

### Ad Inspector

```dart
await DkmadsSsp.presentAdInspector();
```

### Native

```dart
final native = await DkmadsSsp.loadNative(
  adUnitId: 'NATIVE_UUID',
  width: 320,
  height: 50,
);
// native.headline, native.creativeUrl, native.callToAction — or use DkmadsBannerAd for drop-in
```

See [Native ad SDK](../NATIVE_AD_SDK.md).

### Rewarded

```dart
final rewarded = await DkmadsSsp.loadRewarded(
  adUnitId: 'REWARDED_UUID',
  width: 320,
  height: 480,
);
if (rewarded.hasFill) {
  await DkmadsSsp.showRewarded(
    adUnitId: 'REWARDED_UUID',
    onEvent: (event, payload) {
      if (event == 'earned_reward') {
        // Grant reward here.
      }
    },
  );
}
```

### Video telemetry

```dart
await DkmadsSsp.trackVideoLifecycle(
  adUnitId: 'VIDEO_UUID',
  skippable: true,
  onEvent: (name, payload) => print('$name $payload'),
);

await DkmadsSsp.emitVideoEvent(
  adUnitId: 'VIDEO_UUID',
  eventName: 'video_start',
  payload: {'position_ms': 0},
);
```

## `DkmadsAdResult` fields

Aligned with native `Ad`: `videoUrl`, `html5EntryUrl`, `isVideo`, `isHtml5`, `hasFill`, `campaignId`, `creativeId`, `videoTemplate`, `ctaLabel`, `ctaPosition`, `companionImageUrl`, `showCompanionClick`, `skippable`, `skipAfterSec`, `unitFormat`, `placementContext`, plus `adm`, `creativeUrl`, `clickUrl`, `reason`, `requestId`, `dsp`, `price`. Native loads also expose `headline`, `body`, `callToAction`, `advertiser`, `iconUrl`.

Targeting: [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md).

Native guides: [iOS](./ios.md) · [Android](./android.md).
