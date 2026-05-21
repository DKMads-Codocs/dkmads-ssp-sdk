# Flutter SDK Integration (Bridge)

The **dkmads_ssp** plugin (v0.2.0) bridges to native **iOS/Android SDK v0.4.2** (`DKMadsInterstitialAd`, `DKMadsResponseInfo` on `DkmadsAdResult`, IAB interstitial sizes).

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

**Local path** (monorepo or vendor checkout):

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
      ref: sdk-0.4.2   # release tag (sdk-<semver>)
```

```bash
flutter pub get
```

### 2) Install native iOS SDK

In `ios/Podfile` (see [iOS install](./ios.md)):

```ruby
pod 'DKMadsSSPSDK',
    :git => 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git',
    :tag => 'sdk-0.4.2',
    :podspec => 'ios/DKMadsSSPSDK.podspec'
```

Then `cd ios && pod install`.

### 3. Android native SDK

Add `com.dkmads.ssp:ssp-android:0.4.2` per [Android Installation](./android.md).

### Example app

`sdk/flutter/example/`

## Current capability

- Initialize native SDK (`integrationKey`, optional `propertyId/propertyCode`, `baseUrl`, `debug`)
- Set consent / user data
- **`setTargetingSignals`** — structured demographics, geo, interests (native bridge)
- **`syncFirstPartyProfile`** — optional FPD for Audiences
- **`registerAdUnit`** — IAB size tokens for interstitial/banner (native `SSPSDK.registerAdUnit`)
- **`loadBanner`** — native bid + creative payload (`adm`, `videoUrl`, `isVideo`, …)
- **`loadInterstitial`** + **`showInterstitial`** — native `DKMadsInterstitialAd` fullscreen UI (iOS/Android)
- Track/emit video lifecycle telemetry

> Flutter does not ship `PlatformView` widgets or an **instream** bridge yet. Use **`showInterstitial`** for fullscreen (native UI), **`loadBanner`** / **`loadInterstitial`** JSON for custom render, or **`trackVideoLifecycle`** + your player for video quartiles. Native instream: use iOS/Android SDK directly in platform channels if needed.

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

### Banner

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

Aligned with native `Ad`: `videoUrl`, `html5EntryUrl`, `isVideo`, `isHtml5`, `hasFill`, `campaignId`, `creativeId`, plus `adm`, `creativeUrl`, `clickUrl`, `reason`, `requestId`, `dsp`, `price`.

Targeting: [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md).

Native guides: [iOS](./ios.md) · [Android](./android.md).
