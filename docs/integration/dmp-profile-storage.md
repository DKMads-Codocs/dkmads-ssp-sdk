# SSP FPD vs DMP profile storage

Operators linking **DKMads DMP** to an SSP workspace should avoid maintaining two competing profile stores.

---

## When DMP is linked (recommended)

| Data path | Where profiles live | Use for |
|-----------|---------------------|---------|
| **DMP SDK** → DMP ingest | DMP (`dmp_profiles`, audiences) | Canonical traits, segments, bid-time eval |
| **SSP SDK** → bid/events | SSP (`raw_events`, reporting) | Ad delivery, identity keys only |
| **SSP FPD forward** (optional) | DMP via `POST /v1/ingest/fpd/mobile` | Publishers using `syncFirstPartyProfile()` without DMP SDK |

Configure in **Integrations → DKMads DMP**:

- **Targeting source:** `hybrid` (default) or `dmp` when audiences should come from DMP only.
- **SSP-only FPD forward:** On when publishers do not embed the DMP SDK but still call SSP `syncFirstPartyProfile()`.

---

## When exchange strict mode is on

`privacy_settings.exchange_strict_mode = true` blocks SSP `POST /api/public/v1/fpd/web|mobile`.

Publishers must use the **DMP SDK** for first-party data, or enable **FPD forward** so SSP upserts are relayed to DMP (not stored for exchange use).

---

## What not to do

- Do **not** build house audiences only in SSP FPD when DMP is active — use DMP audience compute + campaign picker.
- Do **not** expect SSP local `web_user_profiles` / `mobile_user_profiles` to match DMP after forward — DMP is canonical for eval.
- Do **not** pass different `device_pid` values to DMP ingest vs SSP bids — use [identity bridge](./dmp-identity.md).

---

## Property-level references

On **Properties → Edit**, optional fields help onboarding:

- **DMP property ID** — UUID from DMP Properties (must match `property_ssp_links` on DMP).
- **DMP app key** — publisher reference for SDK init snippets (workspace link still required).

---

## Related

- [DMP identity bridge](./dmp-identity.md)
- [DMP FPD forward](./dmp-fpd-forward.md)
- [Targeting signals](../TARGETING_SIGNALS.md)
