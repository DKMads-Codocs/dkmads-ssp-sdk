# DMP co-init (`dmpAppKey`)

Phase 5 publisher convenience: pass your **DMP app key** when initializing SSP and the SDK will initialize DMP (when present), then link `device_pid` / `user_pid` for bid-time audience eval.

Prerequisites: [DMP identity bridge](./dmp-identity.md) — workspace link active on SSP.

---

## Web (one-liner)

### Imperative

```javascript
SSP.init({
  integrationKey: 'your-ssp-key',
  endpoint: 'https://ssp.dkmads.com',
  dmpAppKey: 'dmp_live_...',
  // optional:
  dmpApiHost: 'https://ingest.dmp.dkmads.com',
  dmpScriptUrl: 'https://dmp.dkmads.com/sdk/dmp-sdk.js',
});
```

When `window.DMP` is not already on the page, SSP loads `dmpScriptUrl` (default derived from `dmpApiHost`), calls `DMP.init()`, then `SSP.linkDmpIdentity()`.

Manual retry:

```javascript
await SSP.coInitDmp({ dmpAppKey: 'dmp_live_...' });
```

### Pasteable tag

```html
<script async src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_SSP_KEY"
        data-dmp-app-key="dmp_live_..."
        data-dmp-api-host="https://ingest.dmp.dkmads.com"></script>
```

`data-dmp-app-key` implies `useDmpIdentity`.

---

## Android

Add the DMP Android SDK to your app (`com.dkmads.dmp`). SSP uses **reflection** — no hard Gradle dependency from SSP → DMP.

```kotlin
SSPSDK.initialize(
  context,
  Config(
    integrationKey = "your-ssp-key",
    dmpAppKey = "dmp_live_...",
    dmpApiHost = "https://ingest.dmp.dkmads.com", // optional
  ),
)
```

If DMP is not on the classpath, SSP falls back to `linkDmpIdentity()` from SharedPreferences.

```kotlin
SSPSDK.coInitDmp(appKey = "dmp_live_...")
```

---

## iOS

Link **DKMadsDMP** in your Xcode project / SPM. When the module is present, co-init runs asynchronously after `initialize`.

```swift
let cfg = SSPSDKConfig(integrationKey: "your-ssp-key")
cfg.dmpAppKey = "dmp_live_..."
cfg.dmpApiHost = "https://ingest.dmp.dkmads.com" // optional
SSPSDK.shared.initialize(with: cfg)
```

Without DKMadsDMP linked, SSP attempts storage-only `linkDmpIdentity()`.

```swift
SSPSDK.shared.coInitDmp(appKey: "dmp_live_...")
```

---

## Flutter

```dart
await DkmadsSsp.initialize(
  integrationKey: 'your-ssp-key',
  dmpAppKey: 'dmp_live_...',
  dmpApiHost: 'https://ingest.dmp.dkmads.com',
);

// or later:
await DkmadsSsp.coInitDmp(dmpAppKey: 'dmp_live_...');
```

---

## Unity

```csharp
DKMadsSdk.Initialize(
  integrationKey: "your-ssp-key",
  propertyId: null,
  propertyCode: null,
  dmpAppKey: "dmp_live_...",
  dmpApiHost: "https://ingest.dmp.dkmads.com"
);
```

---

## Verify

| Platform | Check |
|----------|--------|
| Web | `SSP.diagnostics()` → `identity_source: 'dmp_storage'` or `'dmp_explicit'`, `dmp_app_key_set: true` |
| Android | `SSPSDK.identitySource()` |
| iOS | `SSPSDK.shared.identitySourceLabel()` |

---

## Related

- [DMP identity bridge](./dmp-identity.md)
- [DMP FPD forward](./dmp-fpd-forward.md)
