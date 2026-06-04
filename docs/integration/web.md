# Web SDK integration guide

Integrate display, video, and audio ads on any modern website using a single hosted JavaScript file—no bundler required.

**Audience:** web developers and ad-ops  
**Prerequisites:** web property, integration key, and at least one ad unit in the dashboard  
**Mobile apps:** see [iOS](./ios.md), [Android](./android.md), [Flutter](./flutter.md), or [Unity](./unity.md)

**Hub:** [Implementation guide](../SDK_IMPLEMENTATION_GUIDE.md) · [SDK contract](../SDK_CONTRACT.md)

**Version:** aligned with all publisher SDKs via `sdk/VERSION` in the monorepo (same semver as iOS/Android `0.5.x` releases). Web exposes `SDK_VERSION` in `SSP.diagnostics()` and event telemetry.

---

## 1. Add the SDK script

Load the hosted SDK once per page. Use a tiny **inline bootstrap** so `window.ssp`
exists **before** the `async` loader runs, then the main script tag.

```html
<script>window.ssp = window.ssp || [];</script>
<script async
        src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_INTEGRATION_KEY"></script>
```

**Behavior**

- `data-property-key` sets the property integration key (required for pasteable boot).
- The API base URL defaults to the **origin of this script’s `src`** (so the tag
  and `/api/public/v1/bid` stay on the same host). Override with
  `data-endpoint="https://ssp.dkmads.com"` when you **self-host** the file on
  your own domain but want bids to hit the SSP.
- `window.ssp` is a **command queue** (`ssp.push(function () { … })`). Callbacks
  run after `SSP.init` (including pasteable auto-boot). This matches how
  publishers stack tags before async scripts resolve.

**Why `/api/public/sp.js` (not `/sdk/ssp-sdk.js`) on many hosts**

If the dashboard is a static SPA behind the same origin, reverse proxies often
map unknown paths like `/sdk/...` to `index.html` (`Content-Type: text/html`).
Browsers then block execution with **`net::ERR_BLOCKED_BY_ORB`**. The API route
`/api/public/sp.js` is served by Node with **`application/javascript`**, which
avoids that failure mode. The same bundle is also available at
`/sdk/ssp-sdk.js` when that path is routed to the API (or static files)
correctly.

**Alternate URL (filter lists)**

Some browsers or networks block URLs that match filter lists. If `sp.js` is
blocked, self-host the SDK bundle from your DKMads deployment (same file as
`/api/public/sp.js`) and set `data-endpoint` to the SSP origin.

The SDK registers `window.SSP` for imperative use (`SSP.init`, `SSP.scan`,
`SSP.display`, …).

---

## 2. Render an ad unit (auto-rendering)

Drop a placeholder anywhere in the DOM. After boot, the SDK scans for
`[data-ssp-ad-unit]` and requests a bid for each slot.

```html
<div data-ssp-ad-unit="AD_UNIT_ID"
     data-ssp-size="300x250"></div>
```

The integration key comes from the **script tag** (`data-property-key`), not
from each slot (one property key per page load is the usual model).

**Attributes**

| Attribute               | Required | Description                                    |
|-------------------------|----------|------------------------------------------------|
| `data-ssp-ad-unit`      | ✅       | Ad unit UUID (from the dashboard).             |
| `data-ssp-size`         | optional | `WxH` or `auto` for responsive ad units.       |
| `data-ssp-sizes`        | optional | Comma-separated multi-size list (e.g. `728x90,300x250`). |
| `data-ssp-placement`    | optional | Placement code (e.g. `article_page`).          |
| `data-ssp-refresh`      | optional | Declared auto-refresh interval in seconds (**minimum 30**). Required before `SSP.refresh()` or timed rotation in the same slot. |
| `data-ssp-allow-duplicate` | optional | Allow multiple DOM slots with the same ad unit ID (default: warn in debug only). |

**Refresh policy:** Undeclared background refresh is blocked server-side and in the SDK. See [AD_REFRESH_POLICY.md](../AD_REFRESH_POLICY.md). Use `SSP.refresh(slot, { refreshReason: 'viewable_timer' })` only after the slot was viewable and the declared interval elapsed; real navigation may use `refreshReason: 'navigation'`.

When `refresh_interval_sec` is set on the ad unit in the dashboard, the bid response includes it and the SDK applies it to the slot (and may schedule viewable auto-refresh after the first viewable impression). You do not need `data-ssp-refresh` if the dashboard value is set.

---

## 3. Instream video (pause content → ad → resume)

For players you control (not IMA-only VAST), use the instream coordinator:

```js
var loader = SSP.createInstreamLoader({
  adContainer: document.getElementById('ad-break'),
  onPauseContent: function () { myPlayer.pause(); },
  onResumeContent: function () { myPlayer.play(); },
});
loader.requestAds({ adUnitId: 'AD_UNIT_UUID', width: 640, height: 360 });
```

Content pauses before the bid; it resumes after the ad completes, is skipped, or fails.

---

## 4. Fullscreen, splash, and native

**Interstitial** (codeless overlay):

```js
SSP.displayInterstitial('INTERSTITIAL_UUID', {
  trigger: 'page_load', // or 'exit_intent' | 'manual'
  sizes: ['320x480', '300x600'],
  skipAfterSec: 5,
});
```

**Splash** (dashboard format `splash` — same overlay API as mobile app open):

```js
SSP.displaySplash('SPLASH_UUID', { trigger: 'page_load' });
```

**Native** (in-feed): use a slot with `data-ssp-ad-unit` on a **native** ad unit. The SDK renders a default card from bid `meta` (`headline`, `body`, `cta_label`, `image_url`). For custom layouts, call `SSP.requestAd` and read `winner.native_assets` after fill.

```html
<div data-ssp-ad-unit="NATIVE_UUID" data-ssp-size="320x50"></div>
```

---

## 5. Consent (IAB TCF 2.2 & GPP)

The SDK automatically reads any installed TCF 2.2 / GPP CMP (via
`window.__tcfapi` / `window.__gpp`). If the user has not given consent for
purposes that the platform requires (e.g. purpose 1 for FPD), the SDK:

- Still serves contextual ads (no personal identifiers sent).
- Does **not** collect or upload first-party data.
- Sends `regs.gdpr = 1` in bid requests so downstream DSPs comply.

You can explicitly set consent for environments without a CMP:

```js
SSP.setConsent({
  gdpr_applies: true,
  tcf_string: 'CPx...',     // optional, when you have a TCF string
  gpp_string: 'DBABMA~...'   // optional
});
```

---

## 6. First-party data (optional, consent-gated)

If you want to enrich audience segments with behavioral data:

```js
SSP.track('page_view', { category: 'finance', article_id: '123' });
SSP.track('scroll_depth', { pct: 75 });
SSP.track('signup_complete');
```

First-party signals are sent to `/api/public/v1/fpd/web` (when enabled) and telemetry is
batched to `/api/public/v1/events`. The server rejects ingestion if consent is missing or
invalid — you will see a 403 in DevTools Network tab.

---

## 7. Video lifecycle parity (cross-platform)

For web video players, use `SSP.bindVideo(videoElement, opts)` so event naming
matches iOS/Android/Flutter/Unity lifecycle telemetry:

- Quartiles: `video_start`, `video_25`, `video_50`, `video_75`, `video_100`
- Playback controls: `video_pause`, `video_resume`, `video_skip`
- Audio: `video_mute`, `video_unmute`
- Errors and close: `video_error`, `video_close`
- Viewability: `video_viewable`

---

## 8. Verify your integration

Run in the browser console on a page with the SDK loaded:

```js
SSP.diagnostics(); // includes can_request_ads, last_bid
SSP.lastBidDiagnostics(); // { reason, request_id, dsp, price } — parity with mobile Ad Inspector lite
```

Optional consent gate before bids (mobile `requireConsentBeforeAds` parity):

```js
SSP.init({ integrationKey: '...', requireConsentBeforeAds: true });
if (!SSP.canRequestAds()) return; // wait for CMP / SSP.setConsent
```

On the dashboard, confirm:

- **Inventory → Properties**: "Last SDK seen" updates within a minute.
- **Inventory → Ad Units**: 7d request/impression counters start growing.
- **First-Party Data**: web profiles increment if you call `trackEvent`.

---

## Troubleshooting

| Symptom                                  | Likely cause                            |
|------------------------------------------|-----------------------------------------|
| `net::ERR_BLOCKED_BY_ORB` on script (200 response) | Response is **`text/html`** (often SPA `index.html`) instead of JavaScript — fix proxy routing for `/sdk/`, or load **`/api/public/sp.js`** (dashboard default). |
| `net::ERR_BLOCKED_BY_CLIENT` on script   | Client-side block (DNS filter, “ad blocking” at OS/network, strict enterprise policy, or some Brave/Safari modes — not always an extension). Try `/api/public/sp.js`, self-host the bundle on your origin + `data-endpoint`, or another network. |
| `401 Unauthorized` from `/api/public/v1/bid` | Wrong integration key or property inactive |
| `403 Forbidden` from `/api/public/v1/fpd/web` | Consent missing (TCF purpose 1 or gdpr_applies=true without tcf_string) |
| Ad unit stays blank                      | Ad unit status is `inactive`, no eligible bidders, or `floor_price` too high |
| `429 Too Many Requests`                  | Per-property rate limit; inspect `Retry-After` header |
| Reward callbacks never fire              | DSP returned non-rewarded creative; reject in waterfall |
| `ssp.push` never runs                    | Ensure `SSP.init` ran (pasteable tag with `data-property-key`, or call `SSP.init` before pushing). |

See also: [SDK Implementation Guide](./SDK_IMPLEMENTATION_GUIDE.md) (troubleshooting).
