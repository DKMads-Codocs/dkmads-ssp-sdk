# SDK metrics reference

Events are sent to `POST /api/public/v1/events` and rolled up in the dashboard.

## Banner / display

| Metric | SDK event | Auto on `DKMadsBannerAdView`? | Auto on web `SSP.bind`? |
|--------|-----------|-------------------------------|------------------------|
| Served | `ad_impression` (from bid) + `impression` | Yes | Yes |
| Measurable | `measurable_impression` | Yes | Yes |
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

### Playback metrics

| Metric | SDK event | Requires |
|--------|-----------|----------|
| Start | `video_start` | `DKMadsVideoAdController.attach` / `trackVideoLifecycle` / `SSP.bindVideo` |
| 1st quartile | `video_25` | Same |
| 2nd quartile | `video_50` | Same |
| 3rd quartile | `video_75` | Same |
| Complete | `video_100` | Same |
| Viewable | `video_viewable` | Same |
| Skip | `video_skip` | Same |
| Pause / resume | `video_pause`, `video_resume` | Same |
| Mute / unmute | `video_mute`, `video_unmute` | Same |
| Error | `video_error` | Same |

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
