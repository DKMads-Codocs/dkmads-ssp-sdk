# Unity SDK integration guide

The **com.dkmads.ssp** package bridges Unity to native iOS and Android SDKs for interstitial and video workflows.

**Hub:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [iOS](./ios.md) · [Android](./android.md)

## Prerequisites

- Unity 2019.4+ with iOS and/or Android build support
- Native SDKs for export targets ([iOS](./ios.md), [Android](./android.md))
- DKMads property, integration key, and ad unit UUID

## Installation

| Component | Package / coordinates |
|-----------|------------------------|
| Unity bridge | `com.dkmads.ssp` (`sdk/unity`) |
| Android | `com.dkmads.ssp:ssp-android:0.5.25` |
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

### Samples

- **Quickstart** — `sdk/unity/Samples~/QuickstartSample/` (init, interstitial, app open, inspector)
- **Video lifecycle** — `sdk/unity/Samples~/VideoLifecycleSample/`

## Current capability

- Initialize native SDK with integration key (Android + iOS)
- Pass user data / custom app events
- **`SetTargetingSignals`** / JSON variant (Android + iOS)
- **`LoadAd`** / **`LoadAdWithFormat`** — banner, interstitial, video, splash, etc.
- **`LoadInterstitial`** + **`ShowInterstitial`** — native fullscreen UI
- **`LoadAppOpen`** + **`ShowAppOpen`** — splash / app open
- **`PresentAdInspector`** — last bid diagnostics
- **`LoadNative`** — native format JSON (headline, creativeUrl, cta fields when present in bid)
- **`LoadRewarded`** + **`ShowRewarded`** — native rewarded fullscreen UI
- Forward video lifecycle events to telemetry (`EmitVideoEvent`)
- **Server `render_mode` hint** — `DKMadsAdLoadResult.renderMode` (`renderMode` in JSON) for custom render forks
- **MRAID 2.0 + OMID** — native fullscreen surfaces inherit MRAID 2.0 rich-media and the OMID measurement seam from the native SDK (see [OMID & viewability](../OMID_VIEWABILITY.md))

> Unity has no UGUI banner widget. Use **`LoadInterstitial`** / **`LoadAppOpen`** for native fullscreen, or **`LoadAd`** JSON for custom UI.

## Quickstart

See `Samples~/QuickstartSample/QuickstartSample.cs`.

```csharp
DKMadsSdk.Initialize("YOUR_INTEGRATION_KEY");

// After UMP/CMP — native SDK also auto-reads IAB storage on each load:
DKMadsSdk.SetConsent(new DKMadsConsent {
    gdpr = true,
    consentString = tcfFromCmp,
    usPrivacyString = uspFromCmp,
    attStatus = 3  // iOS only: ATT authorized
});

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

Dashboard format **interstitial**. IAB sizes (320×480), not display pixels. **Pin native SDK `sdk-0.5.25`** — interstitial fit, click-through, 90% letterbox chrome, MRAID 2.0, and the OMID measurement seam are implemented in native iOS/Android (Unity bridge inherits automatically).

```csharp
string json = DKMadsSdk.LoadInterstitial("INTERSTITIAL_UUID", 320, 480);
// if success → native fullscreen:
DKMadsSdk.ShowInterstitial("INTERSTITIAL_UUID");
```

### App open (splash)

```csharp
string json = DKMadsSdk.LoadAppOpen("SPLASH_UUID");
if (json.Contains("\"success\":true"))
    DKMadsSdk.ShowAppOpen("SPLASH_UUID");
```

### Ad Inspector

```csharp
DKMadsSdk.PresentAdInspector();
```

### Native

```csharp
string json = DKMadsSdk.LoadNative("NATIVE_UUID", 320, 50);
// Parse headline, creativeUrl, callToAction from JSON for custom UI
```

See [Native ad SDK](../NATIVE_AD_SDK.md).

### Rewarded

```csharp
string json = DKMadsSdk.LoadRewarded("REWARDED_UUID", 320, 480);
// Parse JSON and check success first
DKMadsSdk.ShowRewarded("REWARDED_UUID");
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
| `renderMode` | Server render hint: `image` / `html5` / `video_native` / `video_web` / `native_assets` / `audio` (primary render fork) |
| `videoTemplate` / `ctaLabel` / `ctaPosition` | Video CTA contract |
| `companionImageUrl` / `showCompanionClick` | Companion rendering contract |
| `skippable` / `skipAfterSec` | Skip controls contract |
| `unitFormat` / `placementContext` | Placement semantics |

## OMID measurement (optional)

OMID verification resources flow through automatically, but the IAB Open Measurement SDK is never bundled. To enable verified measurement, register an OMID provider in the **native host** of the Unity-generated project:

- **Android** — register `DKMadsOmid.provider` in your `Application.onCreate()`.
- **iOS** — set `DKMadsOmid.provider` in your `AppDelegate`.

When no provider is registered, OMID is a no-op and first-party viewability still reports. See [OMID & viewability](../OMID_VIEWABILITY.md).

## Runtime defaults

- Bridge base URL: `https://ssp.dkmads.com`

See [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md), [iOS](./ios.md), [Android](./android.md).
