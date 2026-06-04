# SDK distribution and repository policy

Guidance for DKMads operators on how to ship publisher SDKs securely. Publishers should follow the [platform integration guides](./integration/ios.md); this document is for engineering and release owners.

---

## Should SDKs live in a separate Git repository?

**Recommended for production:** yes — use a **dedicated, publisher-facing SDK repository** (or one repo per platform) that is separate from the SSP dashboard and API codebase.

| Approach | Publisher access | Security | Release cadence |
|----------|------------------|----------|-----------------|
| **Monorepo only** (`ssp-platform` with `sdk/`) | Often grants access to server, DB migrations, admin UI | Higher risk of over-exposure | Simple for internal dev |
| **Separate public SDK repo** | Read-only SDK + samples | Dashboard/API stay private | Tag-driven semver releases |
| **Private SDK repo + binary drops** | Invite-only Git or signed AAR/XCFramework ZIP | Strongest control for enterprise | Manual or CI artifacts |

### What stays in the private platform repo

- API server, auth, billing, admin UI
- Database migrations and runbooks
- DSP connectors and house ad logic
- Secrets (`.env`, keys, Postmark, S3 credentials)
- Unreleased product features

### What belongs in the publisher SDK repo

- `sdk/ios`, `sdk/android`, `sdk/android-module`, `sdk/flutter`, `sdk/unity`
- Public integration docs (or a `docs/` mirror synced on release)
- Sample apps and CHANGELOG per platform
- License and security policy (`SECURITY.md`)

No integration keys, workspace secrets, or production credentials in the SDK repository.

---

## Suggested layout

**Option A — single publisher repo (simplest)**

```text
dkmads-ssp-sdk/                # https://github.com/DKMads-Codocs/dkmads-ssp-sdk
  ios/
  android/
  android-module/
  flutter/
  unity/
  docs/
  CHANGELOG.md
  LICENSE
```

CI in the **platform monorepo** publishes tagged releases into this repo (subtree split, copy job, or manual release PR).

**Option B — platform monorepo + release artifacts only**

Keep developing in `ssp-platform/sdk/*`. On release, CI builds:

- `ssp-android-{version}.aar`
- Optional XCFramework / Swift package archive
- Unity `.unitypackage` or UPM tarball

Publish to GitHub Releases on a **minimal public repo** that contains no server code—only binaries and integration markdown.

---

## Release workflow

1. Bump `sdk/VERSION`, run `bash scripts/sync-sdk-versions.sh`, and add entries in `sdk/*/CHANGELOG.md`.
2. Run contract check: `bash scripts/sdk-contract-check.sh`.
3. Run the release exporter (local or CI):

   ```bash
   chmod +x scripts/publish-sdk-release.sh

   # Preview
   ./scripts/publish-sdk-release.sh 0.4.2 --dry-run

   # Build dist/sdk-release/sdk-0.5.1/ + tarball + SHA256
   ./scripts/publish-sdk-release.sh 0.4.2 --archive-only

   # Tag this monorepo
   ./scripts/publish-sdk-release.sh 0.4.2 --archive-only --tag-monorepo
   git push origin sdk-0.5.1

   # Push to publisher repository
   export SDK_PUBLISH_TOKEN=ghp_...   # PAT with repo scope on dkmads-ssp-sdk
   ./scripts/publish-sdk-release.sh 0.5.1 --skip-android-build
   # default push: https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git

   Full release **with Android AAR** needs JDK 17+ locally (`sdk/android-module/gradlew`) or run the **SDK Release** GitHub Action (Java 17 on Ubuntu).
   ```

4. Update public docs (`docs/integration/*.md`) if versions changed; redeploy dashboard docs.
5. Notify publishers; attach tarball or link to publisher repo tag `sdk-<version>`.

### GitHub Actions

Workflow: **`.github/workflows/sdk-release.yml`** (manual **Actions → SDK Release**).

| Input | Purpose |
|-------|---------|
| `version` | Semver label for tag `sdk-<version>` |
| `push_publisher_repo` | Push staged tree to `SDK_PUBLISH_REPO` |
| `tag_monorepo` | Annotated tag on platform repo |
| `skip_android_build` | Skip AAR / Maven repo in bundle |

**Secrets** (publisher push only):

| Secret | Example |
|--------|---------|
| `SDK_PUBLISH_REPO` | Optional override (default `https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git`) |
| `SDK_PUBLISH_TOKEN` | GitHub PAT with `contents:write` on publisher repo |
| `SDK_PUBLISH_BRANCH` | Optional; default `main` |

Artifacts uploaded: `sdk-release-<version>/` (folder, `.tar.gz`, `.sha256`).

### Release bundle contents

```text
sdk-0.5.1/
  ios/ android/ android-module/ flutter/ unity/
  docs/integration/ …
  artifacts/android-maven/   # when Gradle build ran
  RELEASE.json
  CHECKSUMS.txt
  README.md
```

---

## Security practices

### Repository access

- **Publishers:** read access to SDK repo or download releases only—never to the SSP platform repo.
- **Engineering:** platform repo restricted; SDK repo maintainers limited to client-facing engineers.

### Secrets

- Integration keys are created in the **dashboard** and embedded by the publisher in **their** app (`Info.plist`, `gradle`, env)—never committed in SDK source.
- SDK source must not contain DKMads production API keys, database URLs, or signing keystores.

### Supply chain

- Sign Android AAR releases (Gradle signing) where policy requires.
- Publish checksums (`SHA256`) alongside release ZIPs.
- Pin dependencies in SDK modules (Kotlin coroutines, etc.); audit with Dependabot on the SDK repo.

### Binary vs source distribution

| Channel | Use when |
|---------|----------|
| **Git tag + CocoaPods/SPM/Git** | Default for mobile teams comfortable with source |
| **Maven / CocoaPods trunk** | When you are ready for public registry coordinates |
| **Signed AAR / XCFramework ZIP** | Enterprise publishers who block Git submodules |

---

## Keeping monorepo and publisher repo in sync

While both exist:

1. Develop only in `ssp-platform/sdk/*` (single source of truth).
2. On release, run `scripts/publish-sdk-release.sh` (or the **SDK Release** GitHub workflow) to copy `sdk/` + docs into [DKMads-Codocs/dkmads-ssp-sdk](https://github.com/DKMads-Codocs/dkmads-ssp-sdk) and tag `sdk-<version>`.
3. Run the same validation scripts in CI on both repos (SDK repo can run a slim CI: build AAR, `pod lib lint`, Flutter analyze).

Avoid editing the publisher repo by hand without backporting to the monorepo.

---

## Public documentation tone

Publisher-facing pages should use standard sections (**Prerequisites**, **Installation**, **Initialize**)—not informal Q&A. Registry availability and internal repo policy belong here or in release notes, not on the main integration quickstarts.

---

## Related

- [SDK Implementation Guide](./SDK_IMPLEMENTATION_GUIDE.md)
- [Release process](./RELEASE_PROCESS.md)
- [SDK contract](./SDK_CONTRACT.md)
