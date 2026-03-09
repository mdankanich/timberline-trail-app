# Development to Release Runbook

This guide covers the full flow from local development to uploading a build to App Store Connect via GitHub Actions.

## Prerequisites (one-time)

- Repo has these workflows:
  - `.github/workflows/ios-ci-build.yml` (automatic CI build)
  - `.github/workflows/ios-app-store-release.yml` (manual release upload)
- GitHub repo secrets are configured:
  - `ASC_KEY_ID`
  - `ASC_ISSUER_ID`
  - `ASC_PRIVATE_KEY`
  - `GOOGLE_SERVICE_INFO_PLIST_B64`
- Branch protection for `main`:
  - Require pull request before merging
  - Require status checks to pass
  - Required check: `build` (from `iOS CI Build`)
  - Block force pushes

## 1) Start a feature branch

```bash
git checkout main
git pull --ff-only origin main
git checkout -b feature-short-description
```

## 2) Make code changes and commit

```bash
git add .
git commit -m "Describe the change"
git push -u origin feature-short-description
```

## 3) Open Pull Request to `main`

- In GitHub, create PR: `feature-short-description` -> `main`.
- Wait for `iOS CI Build / build` to pass.
- Merge PR.

## 4) Prepare release version bump (release branch)

Create a release branch from latest `main`:

```bash
git checkout main
git pull --ff-only origin main
git checkout -b release-x.y.z
```

Bump version/build:

```bash
scripts/bump_ios_version.sh x.y.z
```

Examples:

```bash
scripts/bump_ios_version.sh 1.0.2
scripts/bump_ios_version.sh 1.0.2 7
```

Commit and push:

```bash
git add "Timberline Trail App.xcodeproj/project.pbxproj" scripts/bump_ios_version.sh
git commit -m "Bump app version to x.y.z (build)"
git push -u origin release-x.y.z
```

Open PR `release-x.y.z` -> `main`, wait for CI, then merge.

## 5) Trigger App Store upload (manual)

- GitHub -> `Actions` -> `iOS App Store Release`
- Click `Run workflow`
  - Branch: `main`
  - `upload_to_app_store = true`
- Wait for these steps to pass:
  - `Archive app (Release, generic iOS device)`
  - `Export IPA`
  - `Upload to App Store Connect`

## 6) Verify in App Store Connect / TestFlight

- App Store Connect -> TestFlight -> iOS Builds
- Confirm new version/build appears
- Complete compliance prompts if shown
- Assign build to internal testing group
- Wait for status to become testable in TestFlight

## 7) If release fails

- Open failed GitHub Actions step logs and inspect first `error:` line.
- Common fixes previously applied:
  - Missing `NSHealthUpdateUsageDescription`
  - Missing `GoogleService-Info.plist` in CI
  - Old Firebase package pin (resolved by updated SPM requirement)
  - App Store auth key location for `altool`

## 8) Repeat for next release

- New feature branch for work
- New `release-x.y.z` branch for version bump and release PR
- Manual run of `iOS App Store Release`
