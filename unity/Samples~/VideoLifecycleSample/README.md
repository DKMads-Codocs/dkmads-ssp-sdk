# Unity Video Lifecycle sample

## Setup

1. Add `com.dkmads.ssp` package to Unity project.
2. Import sample `VideoLifecycleSample`.
3. Attach `VideoLifecycleSample` component to any active GameObject.
4. Fill in `integrationKey`, `propertyId`, `adUnitId`.

## Validate

- Enter Play mode and check initialization logs.
- Use component context menu:
  - `EmitSampleVideoSequence`
  - `TrackCustomEvent`
- Verify logs and telemetry backend events.

## Notes

- This sample focuses on lifecycle bridge validation.
- For real player integrations, map Unity `VideoPlayer` callbacks to:
  - `video_start`, quartiles, `video_pause`, `video_resume`,
  - `video_skip`, `video_mute`, `video_unmute`, `video_100`.
