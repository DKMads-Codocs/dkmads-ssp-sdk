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

## Consent

All identity fields are gated by workspace privacy settings via `applyConsentPolicy` on ingest and bid.
