# iOS quickstart sample

`DKMadsSSPExample` mirrors [60-minute quickstart](../../docs/integration/QUICKSTART.md):

1. Initialize SDK  
2. Load banner (`DKMadsBannerAdView`)  
3. Load & show interstitial  
4. Ad Inspector  

## Setup

```bash
cd sdk/ios/Sample
pod install
open DKMadsSSPExample.xcworkspace
```

Scheme environment variables (optional):

- `DKMADS_INTEGRATION_KEY`
- `DKMADS_BANNER_AD_UNIT_ID`
- `DKMADS_INTERSTITIAL_AD_UNIT_ID`

## Expected result

- Banner: creative renders; status shows load result.
- Interstitial: fullscreen present/dismiss.
- No fill: use Ad Inspector for `reason`, `request_id`, and troubleshooting hints.
