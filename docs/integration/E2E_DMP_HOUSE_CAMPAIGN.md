# E2E: DMP audience → house campaign fill

Operator QA checklist for production sign-off of the DMP ↔ SSP integration (Phase 15 success criterion).

## Prerequisites

- DMP workspace linked to SSP workspace (`workspace_dmp_links.status = active`, mutual verify complete).
- Property on SSP has `dmp_property_id` / `dmp_app_key` set (Integrations → DMP or Properties form).
- House campaign with line item targeting a **DMP audience ID** (not SSP-only FPD audience).
- Test device with SSP SDK **0.5.23+** using `dmpAppKey` co-init or `linkDmpIdentity()`.

## Steps

1. **DMP audience membership** — In DMP, confirm test `device_pid` / `user_pid` is in the target audience (audience preview or Redis membership).
2. **Bid eval** — Trigger `POST /api/public/v1/bid` from the test app; verify server logs or `workspace_dmp_links.settings.eval_stats` show `cache_hit` or `eval_ok` (not `link_403` / `eval_timeout`).
3. **House win** — Campaign should win when bid floor allows; response includes creative `adm` or `native_assets` with `hasFill: true`.
4. **Impression** — Fire `impression_served` event; Reports → period KPIs show delivery for the campaign.
5. **Shadow path (optional)** — Set DMP link `fail_mode = closed` temporarily; bid should not serve when eval fails (verify `reason` in bid response).

## Pass criteria

| Check | Expected |
|-------|----------|
| DMP eval latency p95 | &lt; 50ms (cached) / &lt; 200ms (miss) |
| Audience on bid | `signals.audience_ids` or house targeting includes DMP audience |
| Creative served | Non-empty fill; native_assets-only wins render |
| Eval telemetry | `eval_stats` counters increment in Integrations UI |

## Rollback

- Set link `status = paused` or `targeting_source = ssp` to fall back to SSP FPD audiences only.
- See [dmp-profile-storage.md](./dmp-profile-storage.md) for FPD vs DMP ingest when link is active.

## Related docs

- [dmp-identity.md](./dmp-identity.md)
- [dmp-co-init.md](./dmp-co-init.md)
- DMP repo `docs/RUNBOOK.md` — eval service health
