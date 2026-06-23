# DMP ↔ SSP identity bridge

Publishers running **both** DKMads DMP and SSP SDKs must send the **same** `device_pid` (and `user_pid` when logged in) on DMP ingest and SSP bid requests. Otherwise bid-time audience evaluation returns empty results.

**Prerequisites:** [DMP Phase 1 integration](../DMP_PROJECT_HANDOVER.md) — workspace link configured in SSP Integrations, eval token active.

**Shortcut (Phase 5):** pass `dmpAppKey` on SSP init to co-initialize DMP — see [DMP co-init](./dmp-co-init.md).

---

## Recommended flow (web)

```javascript
import DMP from '@dkmads/dmp-sdk';

// 1. DMP establishes canonical profile + device_pid
await DMP.init({ appKey: 'dmp_live_...' });
await DMP.identify(userId, { 'demographic.age_range': '25-34' });

// 2. SSP — pasteable tag or imperative init
await SSP.init({
  integrationKey: 'your-ssp-integration-key',
  endpoint: 'https://ssp.dkmads.com',
});

// 3. Share identity (pick one)
const { devicePid, userPid } = DMP.getSharedIdentity();
SSP.linkDmpIdentity({ devicePid, userPid });

// — or auto-read DMP localStorage after DMP.init:
SSP.linkDmpIdentity();

// — or init with useDmpIdentity (reads dkmads_dmp_device_pid on boot):
SSP.init({ integrationKey: '...', useDmpIdentity: true });
```

Pasteable script attribute (after DMP has run on the page):

```html
<script async src="https://ssp.dkmads.com/api/public/sp.js"
        data-property-key="YOUR_KEY"
        data-use-dmp-identity="true"></script>
```

---

## SSP API

| Method / option | Platform | Description |
|-----------------|----------|-------------|
| `SSP.linkDmpIdentity({ devicePid?, userPid? })` | Web | Sets bid `device_pid` / `user_pid`. Omits args → reads DMP `localStorage` key `dkmads_dmp_device_pid`. Returns `boolean`. |
| `useDmpIdentity: true` | Web init | Prefer DMP storage over generating `dkmads_ssp_device_pid`. |
| `dmpAppKey` / `SSP.coInitDmp()` | Web init | Co-init DMP SDK + auto-link identity — [co-init guide](./dmp-co-init.md). |
| `data-dmp-app-key` | Web pasteable tag | Same as `dmpAppKey` on `SSP.init`. |
| `SSPSDK.linkDmpIdentity(devicePid?, userPid?)` | Android | Reads DMP `SharedPreferences` (`dkmads_dmp`) when `devicePid` omitted. |
| `useDmpIdentity` | Android `Config` | Same as web init option. |
| `dmpAppKey` / `SSPSDK.coInitDmp()` | Android | Co-init DMP + link — [co-init guide](./dmp-co-init.md). |
| `SSPSDK.shared.linkDmpIdentity(devicePid:userPid:)` | iOS | Reads DMP `UserDefaults` key `dkmads_dmp_device_pid` when omitted. |
| `useDmpIdentity` | iOS `SSPSDKConfig` | Same as web init option. |
| `dmpAppKey` / `coInitDmp()` | iOS | Co-init DMP when DKMadsDMP is linked. |
| `DkmadsSsp.linkDmpIdentity(...)` | Flutter | Bridges to native implementations above. |
| `DkmadsSsp.coInitDmp(...)` | Flutter | Co-init DMP from Flutter. |

Legacy manual path (still supported):

```javascript
SSP.setTargetingSignals({ devicePid: DMP.getDevicePid(), userPid: userId });
```

---

## DMP API

| Method | Description |
|--------|-------------|
| `DMP.getDevicePid()` | Stable pseudonymous id (persisted locally). |
| `DMP.getUserPid()` | Current `identify()` user id, or `null`. |
| `DMP.getSharedIdentity()` | `{ devicePid, userPid }` for SSP. |

Storage keys (for debugging):

| Platform | DMP writes | SSP reads |
|----------|------------|-----------|
| Web | `localStorage['dkmads_dmp_device_pid']` | `linkDmpIdentity()` / `useDmpIdentity` |
| iOS | `UserDefaults['dkmads_dmp_device_pid']` | `DmpIdentityBridge` |
| Android | `SharedPreferences('dkmads_dmp')` keys `dkmads_dmp_device_pid` or legacy `device_pid` | `DmpIdentityBridge` |

---

## Verify

```javascript
SSP.diagnostics();
// identity_source: 'dmp_storage' | 'dmp_explicit' | 'ssp' | 'explicit'
```

### Phase 3 — production hardening

1. **Integrations → DKMads DMP → Verify mutual link** — confirms DMP `workspace_ssp_links` is `active` for this SSP workspace ID.
2. **Test eval** — probes `GET /v1/targeting/evaluate` with your server token.
3. **Eval failure mode** — `fail open` (default) vs `fail closed` (blocks house campaigns that require DMP `audience_ids` when eval errors).
4. Activating SSP link status requires mutual confirmation unless `require_mutual_for_active: false` is set in link settings.

**SSP-only (Option B):** enable **SSP-only FPD forward** to send `syncFirstPartyProfile` / `fpd/*` data to DMP ingest. See [DMP FPD forward](./dmp-fpd-forward.md).

On the SSP dashboard, confirm DMP audiences apply to house campaigns after audience compute completes.

---

## Related

- DMP publisher guide: `dmp.dkmads.com` → `docs/PUBLISHER_INTEGRATION.md`
- SSP web integration: [web.md](./web.md)
- Workspace DMP link UI: **Integrations → DKMads DMP**
