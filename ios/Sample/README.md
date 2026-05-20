# DKMads SSP iOS Sample App

## Setup

1. Create a new iOS App project in Xcode named `DKMadsSSPExample` inside this folder, or open an existing one.
2. Replace generated `AppDelegate.swift` and add `ViewController.swift` from `DKMadsSSPExample/`.
3. Copy `Info.plist` keys as needed.
4. Run:

```bash
cd sdk/ios/Sample
pod install
open DKMadsSSPExample.xcworkspace
```

5. Set scheme environment variables (optional):

- `DKMADS_INTEGRATION_KEY`
- `DKMADS_AD_UNIT_ID`

6. Build and run on a device or simulator.

## Expected result

- Fill: banner renders HTML/image and status shows `loaded=true reason=won`.
- No fill: status shows `reason=no_tiers` or `no_bids` with actionable diagnostics.
