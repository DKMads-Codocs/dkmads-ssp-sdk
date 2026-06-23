# DMP → SSP identity handoff (sample)

Use this pattern after both SDKs are initialized. Requires SSP **0.5.24+** on the [publisher repo](https://github.com/DKMads-Codocs/dkmads-ssp-sdk).

## Web

```javascript
import DMP from '@dkmads/dmp-sdk';

await DMP.init({ appKey: process.env.DMP_APP_KEY });
await SSP.init({
  integrationKey: process.env.SSP_INTEGRATION_KEY,
  endpoint: 'https://ssp.dkmads.com',
});

const { devicePid, userPid } = DMP.getSharedIdentity();
const linked = SSP.linkDmpIdentity({ devicePid, userPid });
console.log('SSP identity linked:', linked, SSP.diagnostics().identity_source);
// identity_source: 'dmp_explicit' | 'dmp_storage' | 'ssp_generated'
```

Shortcut: `SSP.init({ integrationKey, dmpAppKey: process.env.DMP_APP_KEY })` — see [dmp-co-init.md](../../docs/integration/dmp-co-init.md).

## Android (Kotlin)

```kotlin
// After DMP + SSP init
val identity = DmpSdk.getSharedIdentity() // your DMP SDK API
SSPSDK.linkDmpIdentity(identity.devicePid, identity.userPid)
// Or: SSPSDK.init(context, Config(..., dmpAppKey = "dmp_live_..."))
```

## iOS (Swift)

```swift
// After DMP + SSP init
let identity = DmpSdk.shared.getSharedIdentity()
_ = SSPSDK.shared.linkDmpIdentity(devicePid: identity.devicePid, userPid: identity.userPid)
// Or: config.dmpAppKey = "dmp_live_..."
```

## Flutter

```dart
await DkmadsSsp.init(integrationKey: key, useDmpIdentity: true);
await DkmadsSsp.linkDmpIdentity(devicePid: dmpDevicePid, userPid: dmpUserPid);
```

## Verify

1. `SSP.diagnostics()` (web) or support logs — `identity_source` should be `dmp_*`, not `ssp_generated`.
2. Bid request includes the same `device_pid` DMP uses for audience membership.
3. House/DMP-targeted campaign fills when audience rules match.

Full guide: [docs/integration/dmp-identity.md](../../docs/integration/dmp-identity.md).
