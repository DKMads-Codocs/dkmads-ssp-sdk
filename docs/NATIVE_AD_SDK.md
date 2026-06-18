# Native ad SDK integration

Native ads are **component assets** (not a single image): the publisher app renders
the headline, body, CTA, advertiser, icon, main image and optional store data into
its own layout. This follows **OpenRTB Native 1.2** and aligns with AdMob / Meta
Audience Network native asset sets.

Use **`DKMadsNativeAd`** when you build custom in-feed layouts. Use **`DKMadsNativeAdView`** for default WebView/image rendering.

**Related:** [Ad formats](./AD_FORMATS_MATRIX.md) · [iOS](./integration/ios.md) · [Android](./integration/android.md)

## Authoring native creatives (dashboard)

Native creatives are authored as structured assets — no fixed slot size:

- **Advertiser creative library** → **Upload Creative** → Delivery type **Native (component assets)**.
- **Campaign builder** → Ads step → **Ad format = Native** on a creative.

Both capture: **headline** (required), body, CTA label, advertiser/sponsored-by,
**icon (1:1)**, **main image (1.91:1, required)**, and optional store assets
(star rating 0–5, price, downloads, likes). Image ratios are validated on upload.

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

Served on `winner.native_assets` (normalized for house + external DSP wins) and
exposed on each SDK's native asset model (`DKMadsNativeAdAssets` / `nativeAssets`).

| Field | OpenRTB Native 1.2 source | Notes |
|-------|---------------------------|-------|
| `headline` | title asset | Required |
| `body` | data type 2 (`desc`) | |
| `callToAction` / `cta` | data type 12 (`ctatext`) | e.g. "Install" |
| `advertiser` | data type 1 (`sponsored`) | brand / sponsored-by |
| `iconUrl` / `icon_url` | image type 1 (icon, 1:1) | |
| `imageUrl` / `image_url` | image type 3 (main, 1.91:1) | largest image wins |
| `rating` | data type 3 (`rating`) | 0–5 |
| `price` | data type 6/7 (`price`/`saleprice`) | |
| `downloads` | data type 5 (`downloads`) | |
| `likes` | data type 4 (`likes`) | |
| `clickUrl` / `click_url` | `link.url` | |

External DSP wins return the OpenRTB Native response object in `adm`; the server
parses it into the same shape so SDK rendering is identical for house and exchange demand.

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
