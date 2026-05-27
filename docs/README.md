# DKMads publisher documentation

Official integration guides for monetizing web and app inventory with the DKMads SSP.

**Who this is for:** engineering and ad-ops teams at publishers integrating the SDK, configuring privacy and transparency, and optionally enabling Google Exchange demand.

**Get started in the product:** [Documentation home](/docs) · **Dashboard:** Developer → SDK guide

---

## Recommended learning path

| Step | Guide | Time |
|------|--------|------|
| 1 | [60-minute quickstart](./integration/QUICKSTART.md) | ~1 hour |
| 2 | [Implementation guide](./SDK_IMPLEMENTATION_GUIDE.md) | Reference |
| 3 | Platform guide ([Web](./integration/web.md) · [iOS](./integration/ios.md) · [Android](./integration/android.md)) | As needed |
| 4 | [Integration checklist](./SDK_INTEGRATION_CHECKLIST.md) | Before launch |

---

## Core integration

| Guide | Description |
|-------|-------------|
| [Implementation guide](./SDK_IMPLEMENTATION_GUIDE.md) | End-to-end hub: setup, bid API, metrics, troubleshooting |
| [SDK contract](./SDK_CONTRACT.md) | Request/response schema and no-fill reasons |
| [SDK metrics reference](./SDK_METRICS_REFERENCE.md) | Impression, viewability, video, and audio events |
| [Targeting signals](./TARGETING_SIGNALS.md) | Bid payload and campaign targeting |
| [Ad formats](./AD_FORMATS_MATRIX.md) | Banner, video, audio across platforms |
| [Platform parity](./PLATFORM_ALIGNMENT.md) | Feature availability by platform |

---

## Privacy and policy

| Guide | Description |
|-------|-------------|
| [Regional consent matrix](./REGIONAL_CONSENT_MATRIX.md) | GDPR, US state privacy, COPPA |
| [Ad refresh policy](./AD_REFRESH_POLICY.md) | Valid refresh vs invalid traffic |
| [Mobile attribution](./MOBILE_ATTRIBUTION_INVENTORY.md) | ATT, SKAdNetwork, GAID |
| [Publisher Agreement](./legal/PUBLISHER_AGREEMENT.md) | Commercial and compliance summary |
| [DPA template](./legal/DPA_TEMPLATE.md) | Data processing addendum |
| [Processor inventory](./legal/PROCESSOR_INVENTORY.md) | Subprocessors |

---

## Google Exchange (optional)

Available when your workspace is enrolled. Google partnership onboarding is managed by DKMads; publishers configure rollout in the dashboard.

| Guide | Description |
|-------|-------------|
| [SDK Google policy checklist](./SDK_GOOGLE_POLICY_CHECKLIST.md) | TCF, USP, GPP, ATT, GAID by platform |
| [How Google Exchange works](./GOOGLE_EXCHANGE_ARCHITECTURE.md) | Demand model and your responsibilities |
| [Pilot rollout](./GOOGLE_PILOT_ROLLOUT.md) | Testing and live mode in Privacy settings |
| [OMID / viewability](./OMID_VIEWABILITY.md) | Video measurement |

---

## Terminology

| Term | Meaning |
|------|---------|
| **Workspace** | Your organization account in DKMads |
| **Property** | A site or app (web, iOS, or Android) |
| **Integration key** | Credential for bid and event APIs (per property) |
| **Ad unit** | Inventory placement identified by a UUID |
| **Waterfall** | Ordered demand sources evaluated at auction time |

---

## Support

- In-app: **Developer → SDK guide** (workspace-specific snippets)
- Legal: **Privacy & Compliance** in the dashboard
- Product terms: `/privacy` and `/terms`
