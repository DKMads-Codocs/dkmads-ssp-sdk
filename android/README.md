# DKMads SSP Android SDK (v0.5.1)

Kotlin sources in this folder are packaged via `sdk/android-module` as AAR `com.dkmads.ssp:ssp-android`.

## Components

| File | Role |
|------|------|
| `SSPSDK.kt` | Init, bid, consent, user/targeting signals, FPD sync |
| `TargetingSignals.kt` | Structured demographics, geo, interests |
| `DKMadsBannerAdView.kt` | Banner UI + auto viewability + `responseInfo` |
| `DKMadsInterstitialAd.kt` | Fullscreen interstitial (video, image, HTML5) |
| `DKMadsVideoAdView.kt` | Drop-in video / instream playback (VideoView + WebView) |
| `DKMadsInstreamAdsLoader.kt` | IMA-style instream (pause content → ad → resume) |
| `DKMadsVideoAdController.kt` | Bring-your-own-player + quartiles |
| `DKMadsNativeAdView.kt` | Native format image / HTML |
| `DKMadsAudioAdView.kt` | Audio playback (`audio_url` / `adm`) |
| `DKMadsResponseInfo.kt` | Fill diagnostics (`summary`, `request_id`, `dsp`, `price`) |
| `TelemetryManager.kt` | Event batching → `/api/public/v1/events` |

## Quick start

```kotlin
SSPSDK.initialize(context, Config(integrationKey = "KEY", baseUrl = "https://ssp.dkmads.com", debug = true))
SSPSDK.setConsent(gdpr = true, consentString = tcf)
SSPSDK.setTargetingSignals(
  TargetingSignals(
    devicePid = stableDeviceId,
    userPid = userId,
    gender = "M",
    dateOfBirth = "1998-06-15",
    geoCountry = "US",
    interests = listOf("sports"),
    keywords = listOf("football"),
  ),
)
// Optional audience profile for dashboard Audiences:
// lifecycleScope.launch { SSPSDK.syncFirstPartyProfile(context, appBundle) }

val banner = DKMadsBannerAdView(context, adUnitId = "AD_UNIT_UUID", width = 300, height = 50)
banner.load()

// Interstitial (dashboard format = interstitial)
DKMadsInterstitialAd.load(context, "INTERSTITIAL_UNIT", adWidth = 320, adHeight = 480) { ad, err ->
  ad?.show(context)
}
```

`Ad` exposes `videoUrl`, `isVideo`, `isHtml5`, `hasFill`, `creativeUrl`, and `adm`.

See [docs/integration/android.md](../../docs/integration/android.md) and [docs/TARGETING_SIGNALS.md](../../docs/TARGETING_SIGNALS.md).
