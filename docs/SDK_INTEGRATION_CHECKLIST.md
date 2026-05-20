# SDK Integration Checklist (Release Gate)

Use this checklist before public launch.

## A. Dashboard setup (5 min)

- [ ] Property created (iOS or Android type)
- [ ] Integration key copied from property settings
- [ ] Ad unit created and active
- [ ] At least one active campaign + creative matching ad unit size
- [ ] Property waterfall saved (Demand → Waterfall → Save)

## B. SDK setup (10 min)

- [ ] SDK initialized once at app launch
- [ ] `baseUrl = https://ssp.dkmads.com`
- [ ] `debug = true` during integration
- [ ] Consent/user data set before first ad request (if required)
- [ ] Targeting signals set when campaigns use demographics/geo/interests ([TARGETING_SIGNALS.md](TARGETING_SIGNALS.md))
- [ ] `device_pid` stable per install; `user_pid` when logged in

## C. First ad request (10 min)

- [ ] Use **Ad Unit UUID** (not workspace ID)
- [ ] Request includes size (e.g. `300x250`)
- [ ] Observe HTTP 200 from `/api/public/v1/bid`
- [ ] Handle `reason` in callback/logs

## D. Render validation (10 min)

- [ ] If `reason=won`, render `winner.adm` (WebView) or image URL
- [ ] If no fill, show explicit diagnostic (`no_tiers` / `no_bids`)
- [ ] Impression/click events fire after render

## E. API parity curl (2 min)

```bash
curl -sS -X POST 'https://ssp.dkmads.com/api/public/v1/bid' \
  -H 'Content-Type: application/json' \
  -H 'X-Integration-Key: YOUR_INTEGRATION_KEY' \
  -d '{"ad_unit_id":"YOUR_AD_UNIT_UUID","debug":true,"request":{"sizes":["300x250"],"device_type":"mobile","os":"ios"}}'
```

Expected:
- `reason: "won"` when campaign/creative/waterfall are valid
- `reason: "no_tiers"` when waterfall not saved

## F. Go / No-go

- **Go** if all sections A–E pass on iOS and Android.
- **No-go** if any P0 item fails on both platforms.
