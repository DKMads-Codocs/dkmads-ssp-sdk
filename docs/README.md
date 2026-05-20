# DKMads SSP — documentation index

Publisher and operator documentation for the SSP platform, SDKs, and API.

## Start here (publishers)

| Document | Purpose |
|----------|---------|
| **[SDK Implementation Guide](./SDK_IMPLEMENTATION_GUIDE.md)** | Main hub: setup, platforms, targeting, metrics, troubleshooting |
| [60-minute Quickstart](./integration/QUICKSTART.md) | First successful bid end-to-end |
| [SDK Contract](./SDK_CONTRACT.md) | Canonical API + SDK method map |
| [Integration checklist](./SDK_INTEGRATION_CHECKLIST.md) | Pre-launch QA gate |

## Platform integration guides

| Platform | Package | Guide |
|----------|---------|--------|
| Web | Hosted `sp.js` | [integration/web.md](./integration/web.md) |
| iOS | `DKMadsSSPSDK` | [integration/ios.md](./integration/ios.md) |
| Android | `com.dkmads.ssp:ssp-android` | [integration/android.md](./integration/android.md) |
| Flutter | `dkmads_ssp` + native SDKs | [integration/flutter.md](./integration/flutter.md) |
| Unity | `com.dkmads.ssp` + native SDKs | [integration/unity.md](./integration/unity.md) |

**Hub:** [SDK Implementation Guide](./SDK_IMPLEMENTATION_GUIDE.md) · **Operators:** [SDK distribution](./SDK_DISTRIBUTION.md)

## Reference

| Document | Purpose |
|----------|---------|
| [Targeting signals](./TARGETING_SIGNALS.md) | Bid `signals` + campaign targeting schema |
| [SDK metrics](./SDK_METRICS_REFERENCE.md) | Event names (display, video, audio) |
| [Ad formats matrix](./AD_FORMATS_MATRIX.md) | Formats across web, API, SDK |
| [Platform alignment](./PLATFORM_ALIGNMENT.md) | Cross-stack consistency checks |

## Operations & release

| Document | Purpose |
|----------|---------|
| [Release process](./RELEASE_PROCESS.md) | Shipping API + UI + SDK |
| [Launch checklist](./LAUNCH_CHECKLIST.md) | Go-live gates |
| [DB migration runbook](./runbooks/db-migration.md) | Apply `database/migrations/` |
| [Database backup](./runbooks/database-backup.md) | Restore / PITR |
| [OpenAPI](./api/openapi.yaml) | HTTP contract (partial; see SDK Contract for public bid) |

## Identity & reach (AppsFlyer-style roadmap)

| Document | Purpose |
|----------|---------|
| [Identity & reach](./IDENTITY_AND_REACH.md) | Three layers, metrics, OpenRTB mapping |
| [Identity phase status](./IDENTITY_PHASE_STATUS.md) | **Where we are now** (Phases 1–5 checklist) |

## Full DSP (separate repository)

**Building the demand-side product in another project? Start here:**

| Document | Purpose |
|----------|---------|
| **[DSP README](./DSP_README.md)** | **Index — read first when creating the Full DSP** |
| [DSP integration guide](./DSP_INTEGRATION_GUIDE.md) | Architecture, waterfall, HTTP |
| [DSP OpenRTB contract](./DSP_OPENRTB_CONTRACT.md) | Request/response spec |
| [DSP identity & audiences](./DSP_IDENTITY_AND_AUDIENCES.md) | EIDs, frequency, privacy |
| [DSP eventing & billing](./DSP_EVENTING_AND_BILLING.md) | nurl/burl, macros |
| [DSP launch checklist](./DSP_CHECKLIST.md) | Go-live gates |
| [DSP env & ops](./DSP_ENV_AND_OPS.md) | `DKMADS_*` env vars, SLO |
| [OpenRTB fixtures](./dsp-fixtures/) | Example bid request/response JSON |

SSP API: `GET /api/dsp/connect` (authenticated) returns spec version + doc paths.

## Internal / planning

| Document | Purpose |
|----------|---------|
| [SDK public launch plan](./SDK_PUBLIC_LAUNCH_PLAN.md) | Launch milestones |
| [SDK validation checklist](./SDK_VALIDATION_CHECKLIST.md) | QA scripts |
| [Reporting & money policy](./REPORTING_AND_MONEY_POLICY.md) | Metrics and currency rules |

## Repository layout

```text
docs/
├── README.md                    ← you are here
├── SDK_IMPLEMENTATION_GUIDE.md  ← publisher hub
├── SDK_CONTRACT.md
├── integration/                 ← per-platform quickstarts
├── runbooks/                    ← ops playbooks
├── api/                         ← OpenAPI
├── adr/                         ← architecture decisions
└── legal/                       ← DPA, processor inventory
```

**In the dashboard:** open **Developer → SDK guide** (`/w/{workspaceId}/sdk-guide`) for the in-app implementation walkthrough.

**On the web:** browse rendered documentation at **`/docs`** (HTML pages, not raw `.md` files). Examples:

| Topic | URL |
|-------|-----|
| Docs home | `/docs` |
| Web integration | `/docs/integration/web` |
| iOS integration | `/docs/integration/ios` |
| SDK contract | `/docs/SDK_CONTRACT` |
