# Android SDK integration guide

Integrate banner, interstitial, video, instream, native, and audio ads in Android apps. Drop-in views expose **`DKMadsResponseInfo`** for fill diagnostics.

**Hub:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [SDK contract](../SDK_CONTRACT.md) · [Targeting signals](../TARGETING_SIGNALS.md)

## Prerequisites

- minSdk 23+, target/compile SDK 35+
- Kotlin coroutines on the classpath (SDK `loadAd` is suspend-based)
- DKMads property (Android) with a matching package / bundle ID
- **DKMads Android SDK** added per **Installation** below

## Installation

Add the Android library **`com.dkmads.ssp:ssp-android`** to your Gradle project.

| | |
|---|---|
| **Coordinates** | `com.dkmads.ssp:ssp-android:0.5.11` |
| **Repository** | [github.com/DKMads-Codocs/dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk) |

### Install from GitHub Packages (recommended)

DKMads publishes release AARs to **GitHub Packages**. Use a [classic PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with `read:packages`.

**`settings.gradle.kts`**:

```kotlin
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven {
      url = uri("https://maven.pkg.github.com/DKMads-Codocs/dkmads-ssp-sdk")
      credentials {
        username = providers.gradleProperty("gpr.user").get()
        password = providers.gradleProperty("gpr.key").get()
      }
    }
  }
}
```

**`gradle.properties`** (do not commit tokens):

```properties
gpr.user=YOUR_GITHUB_USERNAME
gpr.key=YOUR_GITHUB_PAT
```

**`app/build.gradle.kts`**:

```kotlin
dependencies {
  implementation("com.dkmads.ssp:ssp-android:0.5.11")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
```

**Publish a new release** (maintainers): from `sdk/android-module`, set `GITHUB_ACTOR` and `GITHUB_TOKEN`, then run `scripts/publish-android-sdk-github.sh`.

**Quickstart sample:** copy [`sdk/android/sample/MainActivity.kt`](../../sdk/android/sample/MainActivity.kt) into your app.

### Build from source (Maven local repository)

Clone the SDK repository and publish the release AAR to a local Maven repo:

```bash
git clone https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git
cd dkmads-ssp-sdk/android-module
./gradlew :library:assembleRelease :library:publishReleasePublicationToLocalSdkRepository
```

Artifacts land in `android-module/library/build/repo`.

**`settings.gradle.kts`** (app project):

```kotlin
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven { url = uri("/absolute/path/to/dkmads-ssp-sdk/android-module/library/build/repo") }
  }
}
```

**`app/build.gradle.kts`**:

```kotlin
dependencies {
  implementation("com.dkmads.ssp:ssp-android:0.5.11")
}
```

Sync Gradle. The AAR ships `com.dkmads.ssp.*`; do not copy Kotlin sources into your app module.

### Vendor as a Git submodule

```bash
git submodule add https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git vendor/dkmads-ssp-sdk
cd vendor/dkmads-ssp-sdk/android-module && ./gradlew :library:publishReleasePublicationToLocalSdkRepository
```

Point the `maven { url = … }` repository at `vendor/dkmads-ssp-sdk/android-module/library/build/repo`.

### Prebuilt AAR (enterprise distribution)

When DKMads provides `ssp-android-0.5.11.aar`, add it under `app/libs/`:

```kotlin
dependencies {
  implementation(files("libs/ssp-android-0.5.11.aar"))
}
```

Include Kotlin coroutines (`kotlinx-coroutines-android` or `core`) in your app.

## Initialize

```kotlin
val cfg = Config(
            integrationKey = "YOUR_INTEGRATION_KEY",
  baseUrl = "https://ssp.dkmads.com",
  debug = true
)
SSPSDK.initialize(applicationContext, cfg)
```

## Drop-in banner (recommended — auto viewability)

```kotlin
val banner = DKMadsBannerAdView(context, adUnitId = "AD_UNIT_UUID").apply {
  setAdSize(300, 250)
  listener = object : DKMadsBannerAdView.Listener {
    override fun onAdLoaded(view: DKMadsBannerAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {
      Log.d("DKMads", responseInfo.summary)
    }
    override fun onAdViewableImpression(view: DKMadsBannerAdView) {
      Log.d("DKMads", "Viewable impression recorded")
    }
  }
}
parent.addView(banner)
banner.load()
```

## Manual load API

```kotlin
val result = SSPSDK.loadAd(
  context = this,
  adUnitCode = "AD_UNIT_UUID",
  format = AdFormat.BANNER,
  sizes = listOf(300 to 250),
  placementCode = "optional_placement_code"
)

result.onSuccess { ad ->
  if (ad.id.isBlank()) {
    Log.d("DKMads", "No fill")
  } else {
    Log.d("DKMads", "Winner: ${ad.id}, ${ad.width}x${ad.height}")
    // ad.creativeUrl contains `adm` HTML payload from /bid winner.
  }
}.onFailure { err ->
  Log.e("DKMads", "loadAd failed", err)
}
```

## Consent + user data (optional)

The SDK **auto-reads IAB CMP / UMP SharedPreferences** on init and before each `loadAd`:

- `IABTCF_TCString`, `IABTCF_gdprApplies`
- `IABUSPrivacy_String`, `IABGPP_*`
- **GAID** only when `ConsentState.allowsAdvertisingId()` (TCF + USP opt-out + LAT)

```kotlin
// Optional explicit pass-through — CMP auto-merge runs automatically:
SSPSDK.setConsent(
  gdpr = true,
  ccpa = true,
  consentString = tcfFromUmp,
  usPrivacyString = uspFromUmp,
)

SSPSDK.setTargetingSignals(
  TargetingSignals(
    devicePid = "device_123",
    userPid = "user_abc",
    gender = "M",
    dateOfBirth = "1998-06-15",
    geoCountry = "MM",
    interests = listOf("sports", "news"),
    keywords = listOf("football"),
  ),
)

// lifecycleScope.launch { SSPSDK.syncFirstPartyProfile(context, appBundle = "com.example.app") }

SSPSDK.setUserData(
  mapOf(
    "device_pid" to "device_123",
    "user_pid" to "user_abc",
    "gender" to "M",
    "yob" to 1998
  )
)
```

## Interstitial (fullscreen)

Dashboard ad unit format must be **interstitial** (Fullscreen & breaks — not Native or banner).

Supports **video**, **image**, **HTML5**, and tag/`adm` creatives from `/v1/bid` (`video_url`, `image_url`, `html5_entry_url`, `adm`).

### Drop-in (recommended)

Bid sizes use explicit dimensions, then sizes from `registerAdUnit`, then **320×480** — not raw display pixel dimensions.

```kotlin
SSPSDK.registerAdUnit(
  "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  AdFormat.INTERSTITIAL,
  sizes = listOf(320 to 480, 300 to 600),
)

val interstitial = DKMadsInterstitialAd("YOUR_INTERSTITIAL_AD_UNIT_UUID").apply {
  adWidth = 320
  adHeight = 480
  listener = object : DKMadsInterstitialAd.Listener {
    override fun onAdLoaded(interstitial: DKMadsInterstitialAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
      Log.d("DKMads", responseInfo.summary)
      interstitial.show(this@MainActivity)
    }
    override fun onAdDismissed(interstitial: DKMadsInterstitialAd) { /* resume game */ }
    override fun onAdFailed(interstitial: DKMadsInterstitialAd, message: String, responseInfo: DKMadsResponseInfo?) {
      Log.w("DKMads", "${responseInfo?.summary ?: message}")
    }
  }
}
interstitial.load(this)
```

Or one-shot:

```kotlin
DKMadsInterstitialAd.load(
  context = this,
  adUnitId = "YOUR_INTERSTITIAL_AD_UNIT_UUID",
  adWidth = 320,
  adHeight = 480,
) { interstitial, error ->
  interstitial?.show(this)
}
```

## Rewarded (fullscreen with completion callback)

```kotlin
val rewarded = DKMadsRewardedAd("YOUR_REWARDED_AD_UNIT_UUID").apply {
  listener = object : DKMadsRewardedAd.Listener {
    override fun onAdLoaded(rewarded: DKMadsRewardedAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
      rewarded.show(this@MainActivity)
    }
    override fun onUserEarnedReward(rewarded: DKMadsRewardedAd) {
      // Grant reward here.
    }
  }
}
rewarded.load(this)
```

## App open (splash)

Create an ad unit with dashboard format **splash**, then:

```kotlin
val appOpen = DKMadsAppOpenAd("YOUR_SPLASH_AD_UNIT_UUID").apply {
  listener = object : DKMadsAppOpenAd.Listener {
    override fun onAdLoaded(appOpen: DKMadsAppOpenAd, ad: Ad, responseInfo: DKMadsResponseInfo) {
      appOpen.show(this@MainActivity)
    }
  }
}
appOpen.load(this)
```

## Ad Inspector

```kotlin
DKMadsAdInspector.present(this)
```

Full-screen view of `SSPSDK.lastBidDiagnostics` (request id, reason, latency) plus troubleshooting hints.

### Manual load API

```kotlin
lifecycleScope.launch {
  val result = SSPSDK.loadAd(
    context = this,
    adUnitCode = "AD_UNIT_UUID",
    format = AdFormat.INTERSTITIAL,
    sizes = listOf(320 to 480),
  )
  result.onSuccess { ad ->
    if (!ad.hasFill) return@onSuccess
    when {
      ad.isVideo -> { /* ExoPlayer / VideoView with ad.videoUrl */ }
      ad.isHtml5 || ad.adm.isNotBlank() -> { /* WebView */ }
      ad.creativeUrl.isNotBlank() -> { /* ImageView */ }
    }
  }
}
```

## Video / instream (drop-in)

### Option A — `DKMadsVideoAdView` (recommended)

```kotlin
val videoView = DKMadsVideoAdView(context, adUnitId = "VIDEO_AD_UNIT")
videoView.listener = object : DKMadsVideoAdView.Listener {
  override fun onAdLoaded(view: DKMadsVideoAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {
    Log.d("DKMads", responseInfo.summary)
  }
}
parent.addView(videoView, LayoutParams(MATCH_PARENT, 200.dpToPx()))
videoView.load(width = 640, height = 360, placementContext = "instream_preroll")
```

### Option B — Instream loader (pause content → ad → resume)

Wire ExoPlayer (or any player) via `DKMadsContentPlayback`:

```kotlin
val loader = DKMadsInstreamAdsLoader(
  adContainer = adOverlay,
  onPauseContent = { exoPlayer.pause() },
  onResumeContent = { exoPlayer.play() },
  wasContentPlaying = { exoPlayer.isPlaying },
)
loader.listener = object : DKMadsInstreamAdsLoader.Listener {
  override fun onAdStarted(loader: DKMadsInstreamAdsLoader) {
    Log.d("DKMads", loader.responseInfo?.summary ?: "")
  }
}
loader.requestAds("VIDEO_AD_UNIT", contentPosition = "instream_preroll", width = 640, height = 360)
```

### Option C — Your player + telemetry

```kotlin
val video = DKMadsVideoAdController("VIDEO_AD_UNIT")
video.listener = object : DKMadsVideoAdController.Listener {
  override fun onAdLoaded(ad: Ad, responseInfo: DKMadsResponseInfo) {
    Log.d("DKMads", responseInfo.summary)
    exoPlayer.setMediaItem(MediaItem.fromUri(video.playbackUri()!!))
  }
  override fun onVideoEvent(eventName: String, payload: Map<String, Any?>) {
    Log.d("DKMads", "$eventName $payload")
  }
}
video.load(context, width = 640, height = 360)
video.attach(
  containerView = playerContainer,
  durationMsProvider = { player.duration.coerceAtLeast(0L) },
  currentPositionMsProvider = { player.currentPosition.coerceAtLeast(0L) },
  isPlayingProvider = { player.isPlaying },
  skippable = true,
)
```

## Native

```kotlin
val native = DKMadsNativeAdView(context, adUnitId = "NATIVE_UNIT", width = 300, height = 250)
native.listener = object : DKMadsNativeAdView.Listener {
  override fun onAdLoaded(view: DKMadsNativeAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {
    Log.d("DKMads", responseInfo.summary)
  }
}
parent.addView(native)
native.load()
```

## Audio

```kotlin
val audio = DKMadsAudioAdView(context, adUnitId = "AUDIO_UNIT")
audio.listener = object : DKMadsAudioAdView.Listener {
  override fun onAdLoaded(view: DKMadsAudioAdView, ad: Ad, responseInfo: DKMadsResponseInfo) {
    Log.d("DKMads", responseInfo.summary)
  }
}
audio.load() // autoplay when prepared
```

## Response info on all views

`DKMadsResponseInfo` exposes `reason`, `requestId`, `dsp`, `price`, `loaded`, and `summary` (e.g. `loaded=true reason=won request_id=… dsp=house`). Available on:

- `DKMadsBannerAdView.responseInfo` + `onAdLoaded(…, responseInfo)`
- `DKMadsInterstitialAd.responseInfo`
- `DKMadsVideoAdView` / `DKMadsInstreamAdsLoader`
- `DKMadsNativeAdView`, `DKMadsAudioAdView`

## Video telemetry hooks (advanced)

```kotlin
SSPSDK.trackVideoLifecycle(
  adUnitId = "AD_UNIT_UUID",
  containerView = videoContainer,
  durationMsProvider = { player.duration.coerceAtLeast(0L) },
  currentPositionMsProvider = { player.currentPosition.coerceAtLeast(0L) },
  isPlayingProvider = { player.isPlaying }
) { event, payload ->
  Log.d("SSPVideo", "event=$event payload=$payload")
}
```

## Troubleshooting

- `401 Unauthorized`: wrong or inactive integration key.
- `reason=no_tiers`: property waterfall not saved.
- Winner present but no rendering: host app does not render `adm` markup.

## See also

- [SDK contract](../SDK_CONTRACT.md) · [Targeting signals](../TARGETING_SIGNALS.md) · [Metrics](../SDK_METRICS_REFERENCE.md)
- [sdk/android/README.md](../../sdk/android/README.md)
