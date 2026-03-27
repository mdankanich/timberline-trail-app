# Firestore Trail Sync Schema (Step 1)

This document defines the shared cloud model for GPX trail data, waypoint collaboration, versioning, and history.

## Goals

- Keep local map usable offline.
- Sync local waypoint changes when connectivity returns.
- Keep immutable historical records for reporting/analysis.
- Use last-write-wins for current state while preserving change history.
- Use soft delete for waypoint removal.
- Allow users to choose when to pull new trail updates.

## Collections

### `trails/{trailId}`

Current trail metadata and active version pointer.

Suggested fields:

- `name` (string)
- `currentVersionId` (string)
- `sourceFileName` (string)
- `sourceGPXHash` (string)
- `lastSyncedAt` (timestamp)
- `updatedAt` (timestamp)
- `updatedByUID` (string)
- `updatedByEmail` (string)

### `trails/{trailId}/versions/{versionId}`

Immutable version snapshots created from GPX imports and/or merged changes.

Suggested fields:

- `trailId` (string)
- `baseVersionId` (string|null)
- `fileName` (string)
- `gpxHash` (string)
- `routePointCount` (number)
- `waypointCount` (number)
- `changesSummary` (map): `{ added, edited, softDeleted }`
- `createdAt` (timestamp)
- `createdByUID` (string)
- `createdByEmail` (string)

### `trails/{trailId}/waypoints/{waypointId}`

Latest materialized waypoint state for fast map loading.

Suggested fields:

- `trailId` (string)
- `name` (string)
- `type` (string)
- `dangerLevel` (string|null)
- `summary` (string|null)
- `distanceFromStart` (number)
- `latitude` (number)
- `longitude` (number)
- `seasonTag` (string|null)
- `isDeleted` (bool)
- `deletedAt` (timestamp|null)
- `deletedBy` (string|null)
- `updatedAt` (timestamp)
- `updatedByUID` (string)
- `updatedByEmail` (string|null)

### `trails/{trailId}/changes/{changeId}`

Append-only audit log for all waypoint modifications.

Suggested fields:

- `trailId` (string)
- `waypointId` (string)
- `action` (string): `add | edit | softDelete`
- `seasonTag` (string|null)
- `actorUID` (string)
- `actorEmail` (string|null)
- `changedAt` (timestamp)
- `clientTimestamp` (timestamp|null)
- `previousValue` (map|null)
- `newValue` (map|null)

## Role and Permission Model

- Admin email allowlist (current app requirement): `mdankanich@slovo.org`
- Admin can add/edit/delete from anywhere.
- Regular signed-in users can add/edit only when on-trail (enforced by app logic and validated server-side where possible).
- All writes generate one `changes` record.

## Firestore Security Rules (Draft)

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    // Current admin bootstrap: email allowlist.
    function isAdmin() {
      return isSignedIn()
        && request.auth.token.email != null
        && request.auth.token.email == "mdankanich@slovo.org";
    }

    match /trails/{trailId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();

      match /versions/{versionId} {
        allow read: if isSignedIn();
        allow write: if isAdmin();
      }

      match /waypoints/{waypointId} {
        allow read: if isSignedIn();
        // Admin always allowed.
        // Non-admin write allowed by app workflow; server-side geo validation can be added with Cloud Functions.
        allow write: if isSignedIn();
      }

      match /changes/{changeId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn();
        allow update, delete: if false; // append-only
      }
    }
  }
}
```

## Recommended Indexes

- `trails/{trailId}/waypoints`: `isDeleted ASC`, `distanceFromStart ASC`
- `trails/{trailId}/changes`: `changedAt DESC`
- `trails/{trailId}/changes`: `waypointId ASC`, `changedAt DESC`

## Sync Contract (for next steps)

- Local device stores:
  - `localVersionId`
  - `lastChangeCursor` (timestamp)
  - `pendingOperations` queue
- Server is source of truth for shared state.
- Merge policy for current state: last-write-wins.
- Historical fidelity: every mutation appended to `changes`.
