# DKMads SSP Android module

This Gradle project packages existing SDK sources from `sdk/android` into a publishable Android AAR.

## Build

```bash
cd sdk/android-module
./gradlew :library:assembleRelease
```

## Publish to local repository

```bash
cd sdk/android-module
./gradlew :library:publishReleasePublicationToLocalSdkRepository
```

Published artifacts are written to:

`sdk/android-module/library/build/repo`

## Coordinates

- Group: `com.dkmads.ssp`
- Artifact: `ssp-android`
- Version: `0.4.1`

Adjust in `gradle.properties` before release.

## Integration

Source files live in `sdk/android/`. See [sdk/android/README.md](../android/README.md) and [docs/integration/android.md](../../docs/integration/android.md).
