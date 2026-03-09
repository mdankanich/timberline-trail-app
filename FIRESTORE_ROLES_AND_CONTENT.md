# Firestore Roles and Managed Content

This project now defines two roles:

- `ADMIN`
- `HIKER`

Default behavior:

- New users are assigned `HIKER`.
- `michaeldankanich@gmail.com` is bootstrap-assigned `ADMIN`.

## Profile document shape

Document path:

- `users/{uid}/data/profile`

Minimum fields:

```json
{
  "name": "Hiker Name",
  "photoURI": "optional-string-or-null",
  "role": "HIKER"
}
```

## Admin-managed content collection

Suggested document paths for content you want editable without app release:

- `app_content/safety`
- `app_content/onboarding`
- `app_content/trail_meta`

Rule intent:

- Any signed-in user can read `app_content/*`
- Only `ADMIN` can write `app_content/*`

## Safety content schema (`app_content/safety`)

The app reads emergency key numbers from this Firestore document:

- `app_content/safety`

Example document:

```json
{
  "keyNumbers": [
    { "id": "forest-ranger", "label": "Mt Hood National Forest Ranger", "value": "5036681700" },
    { "id": "hood-river-sheriff", "label": "Hood River County Sheriff", "value": "5413862098" },
    { "id": "oregon-state-police", "label": "Oregon State Police", "value": "5413952424" },
    { "id": "clackamas-sar", "label": "Search & Rescue (Clackamas Co)", "value": "5036558211" },
    { "id": "poison-control", "label": "Poison Control", "value": "18002221222" }
  ]
}
```

Notes:

- `value` should be digits (or include `+` for country code) because the app uses it as `tel:`.
- If Firestore content is missing/empty, app falls back to built-in defaults.

## Rules file

Rules are in:

- `firestore.rules`

## Deploy rules

If you have Firebase CLI configured for this project:

```bash
firebase deploy --only firestore:rules
```

If not configured yet:

```bash
firebase login
firebase use <your-firebase-project-id>
firebase deploy --only firestore:rules
```

## Important security note

Client-side role checks are for UX only. Firestore rules are what enforce access control.
