# DKMads SSP Android module

This Gradle project packages existing SDK sources from `sdk/android` into a publishable Android AAR.

## Prerequisites

- **JDK 17+** (Android Gradle Plugin 8.x). On macOS:

  ```bash
  brew install --cask temurin@17
  export JAVA_HOME=$(/usr/libexec/java_home -v 17)
  ```

- **Android SDK** — install [Android Studio](https://developer.android.com/studio) once, or set `ANDROID_HOME`. The release scripts auto-write `local.properties` from the default Mac path `~/Library/Android/sdk`:

  ```bash
  bash scripts/ensure-android-sdk.sh
  # or: export ANDROID_HOME="$HOME/Library/Android/sdk"
  ```

## Build

```bash
cd sdk/android-module
./gradlew :library:assembleRelease
```

The repo includes **`gradlew`** — you do not need a global Gradle install.

## Publish to Maven Central (maintainers)

Maven Central is the primary channel — consumers add a single Gradle line with
no GitHub PAT:

```kotlin
dependencies {
  implementation("com.dkmads.ssp:ssp-android:0.5.22")
}
```

Publish requires Sonatype OSSRH credentials and an in-memory PGP signing key:

```bash
export OSSRH_USERNAME=...        # Sonatype user token name
export OSSRH_PASSWORD=...        # Sonatype user token secret
export SIGNING_KEY="$(cat private-key.asc)"
export SIGNING_PASSWORD=...      # key passphrase
cd sdk/android-module
./gradlew :library:publishReleasePublicationToMavenCentralRepository
```

Then release the staging repository on [s01.oss.sonatype.org](https://s01.oss.sonatype.org).
CI can do this via the **SDK Release** workflow (`publish_maven_central: true`).

## Publish to GitHub Packages (mirror)

```bash
export GITHUB_ACTOR=your_github_username
export GITHUB_TOKEN=ghp_xxx   # classic PAT with write:packages
bash scripts/publish-android-sdk-github.sh
```

Consumers add the GitHub Packages Maven repo — see [Android integration](../../docs/integration/android.md#install-from-github-packages-recommended).

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
- Version: `0.5.22` (see `sdk/VERSION` — run `scripts/sync-sdk-versions.sh` after bumps)

## Integration

Source files live in `sdk/android/`. See [sdk/android/README.md](../android/README.md) and [docs/integration/android.md](../../docs/integration/android.md).
