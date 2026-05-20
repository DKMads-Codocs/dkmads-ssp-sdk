# Unity SDK Integration (Bridge)

The **com.dkmads.ssp** Unity package (v0.2.0) bridges to native **iOS/Android SDK v0.4.1**.

## Prerequisites

- Unity 2019.4+ with iOS and/or Android build support
- Native SDKs for export targets ([iOS](./ios.md), [Android](./android.md))
- DKMads property, integration key, and ad unit UUID

## Installation

| Component | Package / coordinates |
|-----------|------------------------|
| Unity bridge | `com.dkmads.ssp` (`sdk/unity`) |
| Android | `com.dkmads.ssp:ssp-android:0.4.1` |
| iOS | `DKMadsSSPSDK` |

For web, use the [Web SDK](./web.md).

### 1. Unity package (UPM)

**Package Manager → Add package from disk…**

Select the folder:

```text
/path/to/dkmads-ssp-sdk/unity
```

(`package.json` must be in that folder — package name `com.dkmads.ssp`.)

**Or** add to `Packages/manifest.json`:

```json
{
  "dependencies": {
    "com.dkmads.ssp": "file:../../dkmads-ssp-sdk/unity"
  }
}
```

Clone [dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk) and adjust the path.

### 2. Android export

Follow [Android Installation](./android.md). Unity merges `sdk/unity/Android`; the **ssp-android** AAR must resolve in the generated Gradle project.

### 3. iOS export

Follow [iOS Installation](./ios.md) in the Xcode project Unity generates (CocoaPods or SPM).

### Sample

`sdk/unity/Samples~/VideoLifecycleSample/`

## Current capability

- Initialize native SDK with integration key (Android + iOS)
- Pass user data / custom app events
- **`SetTargetingSignals`** / JSON variant (Android + iOS)
- **`LoadAd`** / **`LoadAdWithFormat`** — banner, interstitial, video, etc. (Android + iOS)
- **`LoadInterstitial`** + **`ShowInterstitial`** — native fullscreen UI (Android + iOS)
- Forward video lifecycle events to telemetry (`EmitVideoEvent`)

> Unity does not ship UGUI widgets or an **instream** bridge. Use **`ShowInterstitial`** for fullscreen (native activity/VC), **`LoadAd`** / **`LoadInterstitial`** JSON for custom UI, or **`EmitVideoEvent`** with your `VideoPlayer` for quartiles.

## Quickstart

```csharp
DKMadsSdk.Initialize("YOUR_INTEGRATION_KEY");

var signals = new DKMadsTargetingSignals {
    DevicePid = "device_123",
    UserPid = "user_abc",
    Gender = "M",
    Age = 28,
    GeoCountry = "US",
    Interests = new[] { "sports" },
};
DKMadsSdk.SetTargetingSignals(signals);

DKMadsSdk.TrackUserEvent("level_complete", "{\"level\":12}");
```

### Banner

```csharp
string json = DKMadsSdk.LoadAd("BANNER_UUID", 300, 250);
// Parse JSON: success, adm, creativeUrl, videoUrl, isVideo, ...
```

### Interstitial (recommended)

Dashboard format **interstitial**. IAB sizes (320×480), not display pixels.

```csharp
string json = DKMadsSdk.LoadInterstitial("INTERSTITIAL_UUID", 320, 480);
// if success → native fullscreen:
DKMadsSdk.ShowInterstitial("INTERSTITIAL_UUID");
```

### Video telemetry

```csharp
DKMadsSdk.EmitVideoEvent("VIDEO_UUID", "video_start", "{\"position_ms\":0}");
```

## JSON load response

Native bridges return fields aligned with `Ad`:

| Field | Description |
|-------|-------------|
| `success` | Fill when creative is renderable |
| `reason` | `won`, `no_fill`, `no_bids`, … |
| `adm` | HTML/tag markup |
| `videoUrl` | MP4/HLS for video interstitials |
| `creativeUrl` | Image URL |
| `html5EntryUrl` | HTML5 entry |
| `isVideo` / `isHtml5` | Creative type hints |

## Runtime defaults

- Bridge base URL: `https://ssp.dkmads.com`

See [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md), [iOS](./ios.md), [Android](./android.md).
