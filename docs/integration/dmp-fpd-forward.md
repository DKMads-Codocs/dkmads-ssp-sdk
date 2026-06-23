# SSP FPD → DMP forward (Option B)

When publishers use the **SSP SDK only** (no DMP SDK), SSP can forward first-party profile data to DMP ingest after each successful FPD upsert.

**Recommended:** dual-SDK with `DMP.identify()` — see [dmp-identity.md](./dmp-identity.md).

---

## How it works

```
Publisher app (SSP SDK only)
  → POST /api/public/v1/fpd/mobile  (or /fpd/web)
  → SSP stores local web_user_profiles / mobile_user_profiles
  → If DMP link active + forward enabled:
       POST DMP /v1/ingest/fpd/mobile
  → DMP stitcher → Redis demographics + audience compute
  → Bid-time GET /v1/targeting/evaluate returns audience_ids
```

Forwarding is **async** (fire-and-forget after SSP upsert succeeds). FPD response is not blocked on DMP latency.

---

## Enable

1. **Integrations → DKMads DMP** — configure link (eval token, mutual link active)
2. Set **SSP-only FPD forward** → **On** (default when link is active)
3. On DMP: map SSP property UUID via `property_ssp_links`
4. Optional: **Test FPD forward** with an SSP property ID

See [SSP FPD vs DMP profile storage](./dmp-profile-storage.md) for when to use forward vs dual-SDK.

Env (server):

```bash
DMP_INGEST_URL=https://ingest.dmp.dkmads.com
# DMP_INGEST_TIMEOUT_MS=3000
```

---

## Settings (`workspace_dmp_links.settings`)

| Key | Default | Description |
|-----|---------|-------------|
| `forward_fpd_to_dmp` | `true` | Forward FPD to DMP after local upsert |
| `dmp_ingest_url` | `DMP_INGEST_URL` env | Override ingest base URL |

Disabled automatically when `privacy_settings.exchange_strict_mode` is on (FPD endpoints return 403).

---

## Signal mapping

SSP FPD payload fields are mapped server-side before POST to DMP:

| SSP field | DMP bridge `signals` |
|-----------|----------------------|
| `gender`, `metadata.demographics.gender` | `gender` |
| `yob`, `age`, `date_of_birth` | `age` / `ageRange` |
| `geo_country`, `metadata.geo_country` | `country` |
| `geo_region` | `region` |
| `interests.tags`, `keywords`, `segments` | `interests.{name}: true` |

Full contract: DMP repo `docs/SSP_FPD_BRIDGE.md`.

---

## Verify

Dashboard: **Integrations → DKMads DMP → Test FPD forward** (requires SSP property UUID linked on DMP).

Publisher: call `SSPSDK.syncFirstPartyProfile()` (mobile) or enable `collectFirstParty` (web), then confirm DMP profile traits update and bid-time eval returns demographics.

---

## Related

- [dmp-identity.md](./dmp-identity.md) — Option A dual-SDK (recommended)
- [DMP_PROJECT_HANDOVER.md](../DMP_PROJECT_HANDOVER.md) — architecture boundary
