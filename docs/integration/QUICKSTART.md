# 60-minute integration quickstart

Get from an empty workspace to a **successful bid and rendered ad** in about one hour.

**Prerequisites:** DKMads account, property created, basic familiarity with your platform (web, iOS, or Android).

**Related:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [SDK contract](../SDK_CONTRACT.md)

---

## Step 1 — Configure the dashboard (10 min)

1. Create a **property** (web, iOS, or Android).
2. Copy the **integration key** from property settings.
3. Create an **ad unit** (e.g. banner 300×250) and note the UUID.
4. Ensure an active **campaign**, line item, and **creative** match the ad unit format and size.
5. Open **Demand → Waterfall** and click **Save**.

---

## Step 2 — Verify the bid API (5 min)

Replace placeholders and run:

```bash
curl -sS -X POST 'https://ssp.dkmads.com/api/public/v1/bid' \
  -H 'Content-Type: application/json' \
  -H 'X-Integration-Key: YOUR_INTEGRATION_KEY' \
  -d '{"ad_unit_id":"YOUR_AD_UNIT_UUID","debug":true,"request":{"sizes":["300x250"],"device_type":"mobile","os":"ios"}}'
```

| Response `reason` | Meaning |
|-------------------|---------|
| `won` | Backend ready — proceed to SDK |
| `no_tiers` | Save the property waterfall |
| `no_bids` | Check campaign, creative, and format |

---

## Step 3 — Integrate the SDK (30 min)

| Platform | Guide |
|----------|--------|
| Web | [Web integration](./web.md) — script tag + slot |
| iOS | [iOS integration](./ios.md) — install SDK, banner or `loadAd` |
| Android | [Android integration](./android.md) — Gradle, banner or `loadAd` |
| Flutter | [Flutter integration](./flutter.md) |
| Unity | [Unity integration](./unity.md) |

**Integration sequence:**

1. Initialize once at app launch or page load.
2. Call `setConsent` when privacy regulations apply.
3. Call `setTargetingSignals` if campaigns use geo, demographics, or interests — [Targeting signals](../TARGETING_SIGNALS.md).
4. Load an ad or use `DKMadsBannerAdView` / `SSP.bind` for automatic viewability metrics.

---

## Step 4 — Render and validate (15 min)

- Render `winner.adm` in a WebView (mobile) or inject into the DOM (web).
- Treat fill as **`adm` or `image_url` present**, not `id` alone.
- Confirm impression events in the dashboard **Reports** or property counters.
- In debug mode, log `reason`, `request_id`, `dsp`, and `price`.

---

## Step 5 — Production gate

Before launch traffic, complete the [SDK integration checklist](../SDK_INTEGRATION_CHECKLIST.md).

**Next steps:** [Ad formats matrix](../AD_FORMATS_MATRIX.md) · [SDK metrics](../SDK_METRICS_REFERENCE.md) · [Google Exchange policy](../SDK_GOOGLE_POLICY_CHECKLIST.md) (if applicable)
