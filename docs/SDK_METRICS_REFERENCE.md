# SDK metrics reference

Telemetry events sent to `POST /api/public/v1/events` and aggregated in **Reports**.

**Principle:** count **served impressions** when the user sees the creative, not when the auction returns a winner.

## Bid win vs served impression

| Metric | When counted | SDK / server event |
|--------|----------------|-------------------|
| **Bid won** | Auction selects a creative (server-side, once per winning bid) | `bid_won` |
| **Served impression** | Creative is **shown** to the user (once per win) | `ad_impression` (native) or `impression` (web `SSP.bind`) |

Do **not** count served impressions on bid response alone. Native drop-in views call `recordAdImpression` when the ad is rendered; custom integrations must call `SSPSDK.recordAdImpression` when they display a creative returned from `loadAd`.

`measurable_impression` and `viewable_impression` are separate funnel metrics and do **not** add to served impressions.

**Fill rate (reporting)** = served impressions ÷ bid wins (capped at 100% in the dashboard when wins are known).

## Banner / display

| Metric | SDK event | Auto on `DKMadsBannerAdView`? | Auto on web `SSP.bind`? |
|--------|-----------|-------------------------------|------------------------|
| Served | `ad_impression` on render | Yes | `impression` on bind |
| Measurable | `measurable_impression` | Yes (viewability attach) | Yes |
| Viewable (IAB 50%/1s) | `viewable_impression` | Yes | Yes |
| Click | `ad_click` | On tap | On click |

## Video

### Click-through (CTR) vs player engagement

Per IAB/VAST practice, **only intentional navigation to the advertiser landing page** counts as a click (`click` / `ad_click` → `daily_reports.clicks`).

| User action | Counted as click? | SDK event |
|-------------|-------------------|-----------|
| **Learn more** CTA / `click_url` | **Yes** | `click` / `ad_click` |
| Play / pause / resume | **No** | `video_pause`, `video_resume` |
| Mute / unmute | **No** | `video_mute`, `video_unmute` |
| Skip / seek | **No** | `video_skip` |
| Quartiles / complete | **No** | `video_start`, `video_25` … `video_100` |
| In-ad overlay tap (non-landing) | **No** | `video_click` → `ad_interactions` (alias) |

Native MP4/HTML players expose a **Learn more** button when `click_url` is set. House video `adm` uses a separate `.dkmads-cta` link (video + controls are not wrapped in `<a>`).
Web SDK video rendering also uses an explicit **overlay CTA** inside the video slot so click-through remains accessible even when the slot has fixed dimensions.

### VAST / IMA players

When `response_format=vast` on `POST /api/public/v1/bid`:

| VAST element | Maps to ingest event |
|--------------|----------------------|
| `<Impression>` | `impression` → `impression_served` |
| `<Tracking event="start">` | `video_start` (audio → `audio_start`) |
| `<Tracking event="firstQuartile">` | `video_25` |
| `<Tracking event="midpoint">` | `video_50` |
| `<Tracking event="thirdQuartile">` | `video_75` |
| `<Tracking event="complete">` | `video_100` |
| `<ClickTracking>` | `click` |
| `<ClickThrough>` | Landing URL only (player opens browser) |

Beacon URL: `GET /api/public/v1/vast/track?p=<signed-token>` (1×1 GIF, 24h token TTL).

### Playback metrics

| Metric | SDK event | Requires |
|--------|-----------|----------|
| Viewable | `video_viewable` | 50% of player in view while playing for **2 consecutive seconds** |
| Start | `video_start` | After `video_viewable` (web + native SDK default) |
| 1st quartile | `video_25` | After `video_viewable`; not retroactive if user scrolls in late |
| 2nd quartile | `video_50` | Same |
| 3rd quartile | `video_75` | Same |
| Complete | `video_100` | Natural end only — **not** fired on Skip |
| Skip | `video_skip` | User skip control or large forward seek |

**Reporting vs VAST beacons:** VAST `<Tracking>` quartiles often fire on media time alone. DKMads dashboard metrics (`video_25` … `video_100`) are **viewability-gated** so completion rate and quartile funnels align with IAB/MRC video viewability (50% / 2s). Raw VAST beacon URLs are unchanged for third-party players.

Pass `requireViewableProgress: false` to `SSP.bindVideo` only if you intentionally want playback-based quartiles (not recommended for publisher reporting).

| Control | SDK event |
|---------|-----------|
| Pause / resume | `video_pause`, `video_resume` |
| Mute / unmute | `video_mute`, `video_unmute` |
| Error | `video_error` |

## HTML5 / rich-media display

Industry-style **engagement** combines click-through plus in-ad interactions, reported as **Engagement rate** in the dashboard.

| Metric | SDK event | How |
|--------|-----------|-----|
| In-ad interaction | `ad_interaction` | Creative calls `parent.postMessage({ type: 'dkmads:interaction', interaction: 'expand' }, '*')` |
| Hover dwell | `engagement_dwell` | Auto on `SSP.bind()` pointer enter/leave (≥30ms) |
| Click-through | `click` | Auto on `SSP.bind()` click (landing URL) |

Aliases accepted on ingest: `html5_interaction`, `interaction`, `rich_media_interaction` → `ad_interaction`.

**Engagement rate (reporting)** = `(clicks + ad_interactions) ÷ measurable impressions` (fallback: served impressions).

## Audio (web primary)

| Metric | SDK event | Requires |
|--------|-----------|----------|
| Start / quartiles / complete | `audio_start`, `audio_25`…`audio_100` | `SSP.bindAudio` |
| Pause / error | `audio_pause`, `audio_error` | Same |

## Native integration entry points

- iOS banner: `DKMadsBannerAdView`
- iOS video: `DKMadsVideoAdController` + your `AVPlayer`
- Android banner: `DKMadsBannerAdView`
- Android video: `DKMadsVideoAdController` + position/duration providers
- Web: `SSP.bind`, `SSP.bindVideo`, `SSP.bindAudio`
