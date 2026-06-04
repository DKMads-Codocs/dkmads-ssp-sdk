# Native ad SDK integration

Use **`DKMadsNativeAd`** when you build custom in-feed layouts. Use **`DKMadsNativeAdView`** for default WebView/image rendering.

**Related:** [Ad formats](./AD_FORMATS_MATRIX.md) · [iOS](./integration/ios.md) · [Android](./integration/android.md)

## iOS

```swift
DKMadsNativeAd.load(adUnitID: "NATIVE_UUID", sizes: [CGSize(width: 320, height: 50)]) { native, error in
  guard let native, let assets = native.assets else { return }
  // Bind assets.headline, assets.imageUrl, assets.callToAction in your UI
}
```

Or drop-in:

```swift
let view = DKMadsNativeAdView(adUnitID: "NATIVE_UUID", adSize: CGSize(width: 320, height: 50))
view.load()
```

## Android

```kotlin
DKMadsNativeAd("NATIVE_UUID").apply {
  listener = object : DKMadsNativeAd.Listener {
    override fun onAdLoaded(native: DKMadsNativeAd, ad: Ad, assets: DKMadsNativeAdAssets, info: DKMadsResponseInfo) {
      // Custom layout
    }
  }
}.load(context)
```

## Asset fields

| Field | Source |
|-------|--------|
| `headline` | Bid `meta` or root keys (`headline`, `native_title`) |
| `body` | `body`, `native_body` |
| `callToAction` | `cta_label` |
| `imageUrl` | `image_url` or `creativeUrl` |
| `clickUrl` | `click_url` |

Populate `meta` on creatives in the dashboard when you need richer native layouts.

## Web

Auto-render on `native` ad unit slots (`data-ssp-ad-unit`), or imperative:

```js
SSP.requestAd({ adUnitId: 'NATIVE_UUID', request: { sizes: ['320x50'] } })
  .then((resp) => {
    const assets = resp.winner && resp.winner.native_assets;
    // headline, body, callToAction, imageUrl, clickUrl
  });
```

Populate creative `meta` in the dashboard for richer layouts.

## Flutter / Unity

- Flutter: `DkmadsSsp.loadNative(...)`  
- Unity: `DKMadsSdk.LoadNative(adUnitId)`
