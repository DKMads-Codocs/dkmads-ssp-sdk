# Targeting signals

Pass contextual and audience signals on each bid request. DKMads merges them with campaign rules configured in your dashboard.

**Platforms:** web, iOS, Android, Flutter, Unity  
**Related:** [SDK contract](./SDK_CONTRACT.md) · [Regional consent matrix](./REGIONAL_CONSENT_MATRIX.md)

## Bid payload shape

```json
{
  "ad_unit_id": "UUID",
  "request": {
    "device_type": "mobile",
    "os": "ios",
    "geo_country": "US",
    "connection_type": "wifi",
    "content_category": "sports",
    "page_type": "article"
  },
  "signals": {
    "user_pid": "user_abc",
    "device_pid": "device_xyz",
    "gender": "M",
    "yob": 1998,
    "geo_country": "US",
    "interests": { "tags": ["sports"], "keywords": ["football"] },
    "keywords": ["football"],
    "segments": ["premium", "sports_fan"],
    "content_category": "sports",
    "page_type": "article",
    "tcf_string": "…",
    "gdpr": true,
    "us_privacy": "1---"
  }
}
```

**Geo:** If `request.geo_country` is omitted, the SSP may infer country from CDN headers or from `signals.geo_country`.

On each bid, the SSP merges publisher signals with stored audience profiles (when consent allows), resolves audience membership, and evaluates campaign targeting.

## SDK entry points

| Platform | Targeting | First-party profile (house campaigns) |
|----------|-----------|----------------------------------------|
| Web | `SSP.setTargetingSignals({ … })` | `SSP.init({ collectFirstParty: true })` or `SSP.sendFirstPartyData` |
| iOS | `SSPSDK.shared.setTargetingSignals(...)` | `SSPSDK.shared.syncFirstPartyProfile()` |
| Android | `SSPSDK.setTargetingSignals(...)` | `SSPSDK.syncFirstPartyProfile()` |
| Flutter | `DkmadsSsp.setTargetingSignals({...})` | `DkmadsSsp.syncFirstPartyProfile()` |
| Unity | `DKMadsSdk.SetTargetingSignals` | Native bridge |

When **exchange strict mode** is enabled, first-party profile sync is blocked for exchange inventory — use a separate DMP product for house-only audiences.

## Campaign targeting (dashboard)

In **Campaigns → Audience targeting**, empty fields mean “no filter” on that dimension.

| Section | You configure | Matched against |
|---------|---------------|-----------------|
| Audiences | Audience lists | Resolved membership at bid time |
| Geography | Countries / regions | `request.geo_country` |
| Demographics | Gender, age range | `signals.gender`, `signals.yob` |
| Device | Device type, OS, connection | `request.device_type`, `request.os`, `request.connection_type` |
| Segments & interests | Segments, keywords | `signals.segments`, `signals.interests`, `signals.keywords` |
| Contextual | Content category, page type | `request.content_category`, `request.page_type` |

## Demographics (DOB or year of birth)

| You send | Example | Stored |
|----------|---------|--------|
| Date of birth | `"1998-06-15"` | Converted to **year of birth only** |
| `yob` | `1998` | Year of birth |
| `age` | `28` | Used at bid time only if YOB not set |

If both DOB and `yob` are sent, **DOB wins**. Full DOB is not retained in audience profiles.

```json
"signals": {
  "date_of_birth": "1998-06-15",
  "gender": "M"
}
```

## Consent

Identity fields (`user_pid`, `device_pid`, IDFA, GAID) are only used when workspace privacy settings and CMP consent allow. See [REGIONAL_CONSENT_MATRIX.md](./REGIONAL_CONSENT_MATRIX.md).

## Video & audio engagement

Attach lifecycle events after render:

- **Video:** `trackVideoLifecycle` (mobile) or `SSP.bindVideo` (web)
- **Audio:** `SSP.bindAudio` (web) or equivalent custom events on mobile

Events include `campaign_id` / `creative_id` from the bid response when available.

## Related

- [SDK Contract](./SDK_CONTRACT.md)
- [Regional consent matrix](./REGIONAL_CONSENT_MATRIX.md)
- [SDK Google policy checklist](./SDK_GOOGLE_POLICY_CHECKLIST.md)
