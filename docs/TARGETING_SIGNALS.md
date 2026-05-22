# Targeting signals (publisher → SSP)

Canonical schema shared by **web**, **iOS**, **Android**, and **Flutter** bridges. Server normalizes in `server/lib/targeting-signals.js`.

## Bid payload shape

```json
{
  "ad_unit_id": "UUID",
  "request": {
    "device_type": "mobile",
    "os": "ios",
    "geo_country": "US",
    "connection_type": "wifi"
  },
  "signals": {
    "user_pid": "user_abc",
    "device_pid": "device_xyz",
    "gender": "M",
    "age": 28,
    "yob": 1998,
    "geo_country": "US",
    "interests": { "tags": ["sports"], "keywords": ["football"] },
    "keywords": ["football"],
    "segments": ["premium"],
    "tcf_string": "…",
    "gdpr": true,
    "us_privacy": "1---"
  }
}
```

Geo resolution order when `geo_country` is omitted: explicit `signals.geo_country` → CDN headers (`CF-IPCountry`, etc.) on the bid request.

## SDK entry points

| Platform | API |
|----------|-----|
| Web | `SSP.setTargetingSignals({ userPid, devicePid, gender, age, interests: ['sports'], … })` |
| Android | `SSPSDK.setTargetingSignals(TargetingSignals(…))` |
| iOS | `SSPSDK.shared.setTargetingSignals(TargetingSignals(…))` |
| Flutter | `DkmadsSsp.setTargetingSignals({...})` |

Optional first-party profile sync (audience builder):

| Platform | API |
|----------|-----|
| Web | `SSP.init({ collectFirstParty: true })` or `SSP.sendFirstPartyData({...})` |
| Android / iOS | `syncFirstPartyProfile()` / `SSPSDK.syncFirstPartyProfile` |
| Flutter | `DkmadsSsp.syncFirstPartyProfile(appBundle: '…')` |

## Campaign targeting (dashboard)

Campaign builder → **Audience targeting** writes JSON used by house ads `matchesTargeting`:

- `audience_ids`, `geos`, `device_types`, `os`
- `demographics.genders`, `demographics.ageRange`
- `behavioral.interests`, `behavioral.keywords`
- `technical.device_types`, `technical.os`, `technical.connection_types`, `technical.geos`
- `contextual.content_categories`, `contextual.page_types` (supported server-side; optional in builder UI)

## DMP-style storage (server)

| Table | Role |
|-------|------|
| `web_user_profiles` | Web FPD: `interests`, `behaviors`, `consent`, `metadata` keyed by `workspace_id` + `device_pid` + `domain` |
| `mobile_user_profiles` | App FPD: same + `events_rollup`, `att_status`, keyed by `workspace_id` + `device_pid` + `app_bundle` |
| `audience_members` | Links profiles → `audiences` with `matched_by_rules` |
| `campaigns.targeting` | Campaign rules JSON (not a user profile; evaluated at bid time) |

Bid flow: `normalizePublisherSignals` → `loadMergedProfileSignals` → resolve `audience_ids` from profile membership → `matchesTargeting(campaign.targeting, signals, request)`.

## Consent

All identity fields are gated by workspace privacy settings via `applyConsentPolicy` on ingest and bid.
