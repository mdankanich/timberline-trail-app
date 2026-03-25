# Trail Navigator Step Plan

Goal: rebuild Map + Navigate into one unified Trail experience, implemented safely one step at a time.

## Working Rule
For each step:
1. Implement only that step.
2. Build and verify.
3. Fix issues.
4. Commit and push.
5. Move to the next step only after green build.

## Current Status
- Step 1: Completed and pushed
- Step 2: Completed and pushed
- Step 3+: Pending

## Step 1 (Completed)
Merge Map and Navigate into a single primary `Trail` tab.
- Remove separate Navigate tab from tab bar.
- Keep shared location tracker.
- Keep map + waypoint management + basic nav info in one screen.

Done in commit: `5501899` (includes step 2; step 1 structure is part of this merged rollout)

## Step 2 (Completed)
Add Google-like route summary panel (expandable details).
- Route summary with time and arrival.
- Start/Stop tracking action.
- Expand/collapse details.
- Show next waypoint, next water, next campsite, remaining distance.

Done in commit: `5501899`

## Step 3 (Next)
Add elevation segment metrics to next targets.
- Elevation gain/loss to next waypoint.
- Elevation gain/loss to next water/campsite.
- Show concise values in route details.

Acceptance:
- Values update with live position.
- No crashes when elevation data is sparse.

## Step 4
Bottom-sheet interaction polish.
- Better hierarchy for summary/details.
- Improved spacing and readability.
- Optional draggable panel behavior (if stable in current architecture).

Acceptance:
- Smooth interaction on device.
- Clear primary hiking actions.

## Step 5
Proactive hiking alerts.
- Off-trail warning threshold.
- Next water/camp reminders by distance/time.
- Steep segment warning.

Acceptance:
- Alerts are informative, not noisy.
- Works offline using local trail + GPS.

## Step 6
Cleanup + QA + release prep.
- Remove/reconcile unused legacy navigation code paths.
- Device testing matrix (offline, denied location, no GPX, active hike).
- Final UI/UX consistency pass.

Acceptance:
- Build green.
- Core hike flow verified on device.

## Per-Step Checklist Template
Use this for each next step:
- [ ] Implement scoped changes
- [ ] Build locally
- [ ] Resolve compile/runtime issues
- [ ] Smoke test key flow
- [ ] Commit with clear message
- [ ] Push to `feature/gpx-import-clean-2026-03-19`

