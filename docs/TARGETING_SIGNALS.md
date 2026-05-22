# Targeting signals (publisher → SSP → DMP profiles)

Canonical schema shared by **web**, **iOS**, **Android**, **Flutter**, and **Unity**. Server normalizes in `server/lib/targeting-signals.js`; campaign rules are stored on `campaigns.targeting` JSONB.

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

Geo resolution order when `geo_country` is omitted on `request`: explicit `signals.geo_country` → CDN headers (`CF-IPCountry`, etc.) on the bid request.

At bid time the server **merges** publisher signals with stored FPD profiles (`web_user_profiles` / `mobile_user_profiles`), resolves **audience membership**, then evaluates **campaign targeting**.

## SDK entry points

| Platform | Targeting API | FPD profile sync |
|----------|---------------|------------------|
| Web | `SSP.setTargetingSignals({ userPid, devicePid, gender, segments, contentCategory, … })` | `SSP.init({ collectFirstParty: true })` or `SSP.sendFirstPartyData` |
| Android | `SSPSDK.setTargetingSignals(TargetingSignals(…))` | `SSPSDK.syncFirstPartyProfile()` |
| iOS | `SSPSDK.shared.setTargetingSignals(TargetingSignals(…))` | `SSPSDK.shared.syncFirstPartyProfile()` |
| Flutter | `DkmadsSsp.setTargetingSignals({...})` | `DkmadsSsp.syncFirstPartyProfile()` |
| Unity | `DKMadsSdk.SetTargetingSignals` / JSON | Native bridge |

Web tag bids now include `device_type`, `os`, and contextual fields on `request` when set via `setTargetingSignals`.

## Campaign targeting (dashboard) — DMP-aligned

Campaign builder → **Audience targeting** writes JSON evaluated by `matchesTargeting` (house ads):

| UI section | Stored JSON | Matched against |
|------------|-------------|-----------------|
| Audiences | `audience_ids` | Profile rows in `audience_members` (server-resolved → `signals.audience_ids`) |
| Geography | `geos`, `demographics.geos`, `technical.geos` | `request.geo_country` |
| Demographics | `demographics.genders`, `age_min` / `age_max` | `signals.gender`, `signals.yob` (age derived server-side) |
| Device & environment | `device_types`, `os`, `technical.connection_types` | `request.device_type`, `request.os`, `request.connection_type` |
| Segments & interests | `segments`, `behavioral.interests`, `behavioral.keywords` | `signals.segments`, `signals.interests`, `signals.keywords` |
| Contextual | `contextual.content_categories`, `contextual.page_types` | `request.content_category`, `request.page_type` |

Leave a dimension empty to serve all users on that dimension.

## Demographics (DOB or YOB → store YOB only)

Publishers may send either:

| Wire field | Example | Stored in DMP |
|------------|---------|---------------|
| `date_of_birth` / `dateOfBirth` / `dob` | `"1998-06-15"` | **No** — converted to `yob` |
| `yob` | `1998` | **`metadata.demographics.yob`** |
| `age` | `28` | **No** — bid-time fallback only |

**Precedence:** valid DOB → `yob = year(dob)`; else explicit `yob`; else snapshot `age` for matching only.

When both DOB and `yob` are sent, **DOB wins** and only one `yob` is stored. Full DOB is stripped before FPD persist.

FPD profiles persist **`metadata.demographics`** (`yob`, `gender` only). `syncFirstPartyProfile` / web FPD ingest merge these fields; bid-time `loadMergedProfileSignals` rehydrates `signals.yob` from the profile.

```json
"signals": {
  "date_of_birth": "1998-06-15",
  "gender": "M"
}
```

## DMP-style storage (server)

| Table | Role |
|-------|------|
| `web_user_profiles` | Web FPD: `interests`, `behaviors`, `consent`, `metadata` (incl. `demographics.yob`) keyed by `workspace_id` + `device_pid` + `domain` |
| `mobile_user_profiles` | App FPD: same + `events_rollup`, `att_status`, keyed by `workspace_id` + `device_pid` + `app_bundle` |
| `audience_members` | Links profiles → `audiences` with `matched_by_rules` |
| `campaigns.targeting` | Campaign delivery rules (not a user profile) |
| `fpd_ingest_jobs` | Audit trail for profile ingest |

Bid pipeline:

1. `normalizePublisherSignals(rawSignals)`
2. `enrichRequestGeo` + `enrichBidRequestFromSignals` (request ← signals)
3. `loadMergedProfileSignals` (FPD merge)
4. Resolve `audience_ids` from `audience_members`
5. `matchesTargeting(campaign.targeting, signals, request)`
6. Ad-unit chip rules via `evaluateChipTargeting`

## Consent

All identity fields are gated by workspace privacy settings via `applyConsentPolicy` on ingest and bid.

## Audio / video engagement

- **Video:** `trackVideoLifecycle` / web `bindVideo` → quartile + viewability events.
- **Audio:** `trackAudioLifecycle` / web `bindAudio` → `audio_start`, `audio_25` … `audio_100`, `audio_pause`.

Both attach `campaign_id` / `creative_id` when available from the bid response (`cid` / `crid`).
