# Release Checklist

Use this checklist for each TestFlight/App Store release.

## 1) Prepare the release

- [ ] Confirm app changes are merged to `main`.
- [ ] Update iOS app version values in `Timberline Trail App.xcodeproj/project.pbxproj`:
  - [ ] `MARKETING_VERSION` (for example `1.0.1`).
  - [ ] `CURRENT_PROJECT_VERSION` (increment build number).
- [ ] Confirm required secrets exist in GitHub repo settings:
  - [ ] `ASC_KEY_ID`
  - [ ] `ASC_ISSUER_ID`
  - [ ] `ASC_PRIVATE_KEY`
  - [ ] `GOOGLE_SERVICE_INFO_PLIST_B64`

## 2) Trigger CI release upload

- [ ] Open GitHub Actions -> `iOS App Store Release`.
- [ ] Click `Run workflow` on `main`.
- [ ] Keep `upload_to_app_store = true`.
- [ ] Wait for all steps to pass, especially:
  - [ ] `Archive app (Release, generic iOS device)`
  - [ ] `Export IPA`
  - [ ] `Upload to App Store Connect`

## 3) Verify in App Store Connect

- [ ] Open App Store Connect -> TestFlight -> iOS Builds.
- [ ] Confirm the new build appears with the expected version/build number.
- [ ] Complete any required compliance/questions if prompted.
- [ ] Add/select internal testing group (for example `TimberlineUAT`).
- [ ] Confirm build state changes to `Testing`.

## 4) Sanity check on device

- [ ] Open TestFlight app on iPhone with the tester Apple ID.
- [ ] Install/update the build.
- [ ] Verify sign-in, map/location, and HealthKit flows.

## 5) Release record

- [ ] Add short release notes (what changed, known issues, rollback note).
- [ ] Tag commit used for upload (optional but recommended).
