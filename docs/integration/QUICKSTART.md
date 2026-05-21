# DKMads SSP — 60-Minute Quickstart

Follow this path for first successful ad request on iOS or Android.

**Full hub:** [SDK Implementation Guide](../SDK_IMPLEMENTATION_GUIDE.md) · **In dashboard:** Developer → SDK guide

## 1) Dashboard (10 min)

1. Create property (iOS or Android).
2. Copy **Integration key** from property settings.
3. Create ad unit (e.g. banner `300x250`).
4. Ensure campaign + creative are active for that size.
5. Open **Demand → Waterfall** and click **Save**.

## 2) API smoke test (2 min)

```bash
curl -sS -X POST 'https://ssp.dkmads.com/api/public/v1/bid' \
  -H 'Content-Type: application/json' \
  -H 'X-Integration-Key: YOUR_INTEGRATION_KEY' \
  -d '{"ad_unit_id":"YOUR_AD_UNIT_UUID","debug":true,"request":{"sizes":["300x250"],"device_type":"mobile","os":"ios"}}'
```

- `reason: "won"` → backend is ready.
- `reason: "no_tiers"` → waterfall not saved for property.

## 3) Install SDK + integrate (30 min)

**Web:** add the [script tag](./web.md) (hosted SDK).

**iOS / Android / Flutter / Unity:** complete **Installation** in the platform guide, then initialize the SDK:

- [iOS](./ios.md#installation) — `DKMadsSSPSDK` v0.4.2
- [Android](./android.md#installation) — `com.dkmads.ssp:ssp-android:0.4.2`
- [Flutter](./flutter.md#installation) — `dkmads_ssp` + native libraries
- [Unity](./unity.md#installation) — `com.dkmads.ssp` UPM package

Then:

1. Initialize + consent.
2. Call **`setTargetingSignals`** (mobile/web) with `device_pid`, optional demographics/geo/interests — see [TARGETING_SIGNALS.md](../TARGETING_SIGNALS.md).
3. Load ad or use `DKMadsBannerAdView` / `SSP.bind` for auto metrics.

Platform guides:

- [iOS](./ios.md)
- [Android](./android.md)
- [Flutter](./flutter.md)
- [Unity](./unity.md)

Canonical contract: [SDK_CONTRACT.md](../SDK_CONTRACT.md)

## 4) Render + verify (15 min)

- Render `winner.adm` in WebView when present.
- Log `reason`, `request_id`, `dsp`, `price` in debug mode.
- Fire impression/click telemetry after visible render.

## 5) Release gate

Complete [SDK Integration Checklist](../SDK_INTEGRATION_CHECKLIST.md) before public launch.
