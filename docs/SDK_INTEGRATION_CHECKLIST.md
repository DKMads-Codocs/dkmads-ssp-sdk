# SDK integration checklist

Use this checklist as a **release gate** before sending production traffic. Complete every section for each platform you ship (web, iOS, Android).

**Related:** [Implementation guide](./SDK_IMPLEMENTATION_GUIDE.md) · [SDK contract](./SDK_CONTRACT.md)

---

## A. Dashboard configuration

- [ ] Property created with correct type (web / iOS / Android)
- [ ] Property status is **active**
- [ ] Integration key stored securely (not committed to public repos)
- [ ] Ad unit created, active, format and size match placement
- [ ] Campaign, line item, and creative active and approved
- [ ] Property waterfall saved (**Demand → Waterfall → Save**)

---

## B. SDK initialization

- [ ] SDK initialized once per app session or page load
- [ ] `baseUrl` points to `https://ssp.dkmads.com` (or your deployment host)
- [ ] `debug` enabled only in non-production builds
- [ ] Consent set before first ad request where required (GDPR, US, ATT)
- [ ] Targeting signals sent when campaigns use geo, demographics, or interests — [Targeting signals](./TARGETING_SIGNALS.md)
- [ ] Stable `device_pid` per install; `user_pid` when user is logged in

---

## C. Ad request

- [ ] Requests use **ad unit UUID** (not workspace ID)
- [ ] Size included for banner/display (e.g. `300x250`)
- [ ] HTTP 200 from `POST /api/public/v1/bid`
- [ ] Application handles all `reason` values without crashing

---

## D. Render and measurement

- [ ] On `won`, creative rendered from `winner.adm` and/or `winner.image_url`
- [ ] On no-fill, user-visible or logged fallback (`no_tiers`, `no_bids`, etc.)
- [ ] Impression fired **after** creative is visible (not on bid response alone)
- [ ] Click-through uses `winner.click_url` when provided

---

## E. API smoke test

```bash
curl -sS -X POST 'https://ssp.dkmads.com/api/public/v1/bid' \
  -H 'Content-Type: application/json' \
  -H 'X-Integration-Key: YOUR_INTEGRATION_KEY' \
  -d '{"ad_unit_id":"YOUR_AD_UNIT_UUID","debug":true,"request":{"sizes":["300x250"],"device_type":"mobile","os":"ios"}}'
```

- [ ] `reason: "won"` with valid inventory, or expected no-fill with clear cause

---

## F. Go / no-go

| Decision | Criteria |
|----------|----------|
| **Go** | Sections A–E pass on every production platform |
| **No-go** | Any blocking item fails on a platform you ship |

---

## Optional — Google Exchange

If enrolled, also complete the [SDK Google policy checklist](./SDK_GOOGLE_POLICY_CHECKLIST.md) and [pilot rollout](./GOOGLE_PILOT_ROLLOUT.md) before enabling live Google demand.
