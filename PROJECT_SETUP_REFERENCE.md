# Timberline Trail App - Project Setup Reference

Last updated: 2026-03-18

## 1) Repo + App Basics

- Xcode project: `Timberline Trail App.xcodeproj`
- Main app target: `Timberline Trail App`
- Main app code: `Timberline Trail App/ContentView.swift` and supporting files in `Timberline Trail App/`
- iOS tests: `Timberline Trail AppTests/`, `Timberline Trail AppUITests/`
- iOS version/build settings live in: `Timberline Trail App.xcodeproj/project.pbxproj`

Current observed app version config (at time of writing):
- `MARKETING_VERSION = 1.0.1`
- `CURRENT_PROJECT_VERSION = 9` (app target config block)

## 2) CI/CD Workflows

### iOS CI Build

Workflow file: `.github/workflows/ios-ci-build.yml`

Triggers:
- `push` to `main`
- `pull_request` targeting `main`

Key behavior:
- Restores `GoogleService-Info.plist` from `GOOGLE_SERVICE_INFO_PLIST_B64` secret (or creates placeholder if missing).
- Removes tracked SwiftPM lock file before resolve:
  - `Timberline Trail App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Runs simulator build:
  - `xcodebuild ... -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO clean build`
- Captures build log in CI and uploads artifact:
  - Artifact name: `xcodebuild-ci-log`

### iOS App Store Release

Workflow file: `.github/workflows/ios-app-store-release.yml`

Trigger:
- manual `workflow_dispatch`

Required secrets:
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY`
- `GOOGLE_SERVICE_INFO_PLIST_B64`

Key behavior:
- Resolves packages (also removes tracked `Package.resolved` first).
- Archives with automatic signing and team `N7QHDL3XGH`.
- Exports IPA and uploads to App Store Connect via `altool`.

## 3) Branch/Release Practice (Important)

- If a fix is only on a feature/release branch, App Store builds from `main` will not include it.
- Always confirm the target commit is in `main` before release:
  - `git branch --contains <commit>`
- Always increment build number for a new upload that should be visible on device/TestFlight.

Recommended release flow:
1. Merge feature branch into `main`.
2. Bump version/build (`scripts/bump_ios_version.sh`).
3. Push `main`.
4. Ensure `iOS CI Build` passes.
5. Run `iOS App Store Release` workflow from `main`.

## 4) HealthKit Integration - Current Behavior

Code location: `Timberline Trail App/ContentView.swift` (`HealthTrainingStore`)

Current read types:
- `HKWorkoutType`
- `flightsClimbed`
- `distanceWalkingRunning`
- `stepCount`

Current metrics behavior:
- Weekly miles combines:
  - workout total distance
  - walking/running distance samples
  - fallback estimate from steps when distance samples are absent (`steps / 2000`)
- Consistency uses active days/workouts over last 4 weeks.
- Live update observers are registered for available Health sample types above.

User permission requirement:
- In Health app, this app must be allowed to read:
  - Workouts
  - Walking + Running Distance
  - Steps
  - Flights Climbed

If permissions are missing, training metrics may remain near zero.

## 5) Known Pitfalls We Hit (Avoid These)

1. Missing compiler error context
- CI summary often only shows `SwiftCompile failed` without the root cause.
- Use `xcodebuild-ci-log` artifact and grep first `error:` line.

2. Scope regression in HealthKit helper
- In `loadRecentQuantitySamples`, `sampleType` must use function parameter `type`, not a local variable from another method.

3. Data mismatch expectation
- Health app steps alone do not guarantee `HKWorkout` entries.
- Training logic must include step/distance quantity samples, not workouts only.

4. Branch mismatch during release
- Successful App Store upload can still ship old behavior if fixes were not merged into `main`.

5. Local `Package.resolved` noise
- CI scripts remove tracked `Package.resolved`; local environments may show it deleted after some operations.
- Before commit/push, restore if needed:
  - `git checkout -- "Timberline Trail App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"`

## 6) Fast Debug Checklist (Before Adding New Features)

1. Pull latest `main`.
2. Verify current CI green on `main`.
3. Confirm version/build intent for next release.
4. For Health features, verify permission matrix and sample types up front.
5. When CI fails, inspect `xcodebuild-ci-log` artifact first `error:` line before code changes.
6. Keep release branch and `main` alignment explicit before shipping.
