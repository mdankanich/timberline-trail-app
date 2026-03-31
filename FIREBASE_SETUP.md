# Firebase + Apple Sign-In Setup

This project now contains Firebase-ready auth code and Apple Sign-In capability wiring.

## 1) Add Firebase Swift packages in Xcode
Open [Timberline Trail App.xcodeproj](/Users/michaeldankanich/Documents/git/app-timberline-trail/Timberline Trail App/Timberline Trail App.xcodeproj) in Xcode, then:

1. `File -> Add Packages...`
2. Package URL: `https://github.com/firebase/firebase-ios-sdk.git`
3. Add products to **Timberline Trail App** target:
   - `FirebaseAuth`
   - `FirebaseCore`
   - `FirebaseFirestore`

## 2) Add `GoogleService-Info.plist`
1. In Firebase console, create/select iOS app with bundle ID:
   - `com.trail.timberline.Timberline-Trail-App`
2. Download `GoogleService-Info.plist`.
3. Add it to `Timberline Trail App/` target in Xcode.

## 3) Enable Firebase Auth providers
In Firebase Console -> Authentication -> Sign-in method:

1. Enable `Email/Password`
2. Enable `Apple`

For Apple provider, use the same Apple Team/App ID configuration as your Xcode target.

## 4) Apple capability in Xcode
This repo already includes an entitlements file:
- [Timberline Trail App.entitlements](/Users/michaeldankanich/Documents/git/app-timberline-trail/Timberline Trail App/Timberline Trail App/Timberline Trail App.entitlements)

Still verify in Xcode:
1. Target -> `Signing & Capabilities`
2. Ensure `Sign In with Apple` is present.

## 5) Build and test
```bash
cd '/Users/michaeldankanich/Documents/git/app-timberline-trail/Timberline Trail App'
xcodebuild -project 'Timberline Trail App.xcodeproj' -scheme 'Timberline Trail App' -destination 'platform=iOS Simulator,name=iPhone 13' test
```

## Notes
- The app currently falls back to local mock auth if Firebase SDK is not linked.
- Once `FirebaseAuth` and `FirebaseCore` are linked, the same auth UI automatically uses Firebase.
- When `FirebaseFirestore` is also linked, profile/trips sync to Firestore under:
  - `users/{uid}/data/profile`
  - `users/{uid}/data/trips`
- Step 2 trail import sync also writes shared trail data under:
  - `trails/{trailId}`
  - `trails/{trailId}/versions/{versionId}`
  - `trails/{trailId}/waypoints/{waypointId}`

## Firestore Rules (Production Hardening Step 1)

This repo now includes:

- `firestore.rules`
- `firestore.indexes.json`
- `firebase.json` (emulator + rules/indexes wiring)
- `firebase/tests/firestore.rules.test.cjs` (rules tests)

Run rules tests locally:

```bash
cd '/Users/michaeldankanich/Documents/git/app-timberline-trail/Timberline Trail App'
npm install
npm run test:rules
```

Deploy rules and indexes:

```bash
cd '/Users/michaeldankanich/Documents/git/app-timberline-trail/Timberline Trail App'
npx firebase deploy --only firestore:rules,firestore:indexes
```
