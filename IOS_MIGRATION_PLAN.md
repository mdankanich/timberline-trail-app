# Timberline iOS Migration Plan (Blueprint -> SwiftUI)

## Source audited
- Blueprint path: `/Users/michaeldankanich/Documents/git/timberline-trail-app`
- Note: this blueprint is React Native/Expo (not Next.js), and contains the business logic to port.

## Business rules extracted

### Identity, onboarding, auth
- App flow: unauthenticated users see Auth screen; authenticated users without profile setup see onboarding; otherwise enter main app.
- Auth methods: email/password + Sign in with Apple.
- Password reset supported.
- Friendly auth error mapping for common Firebase codes.
- Auto-lock: if app backgrounds for configured timeout, force sign-out.
- On user switch, clear prior local app data except stable device identifiers.

### User profile
- Required `name`, optional `photoUri`.
- Persist locally first; mirror to cloud backup.
- Publish searchable profile doc (`publicUsers`) with lowercase name for invite search.

### Trips
- Trip model: `id`, `name`, `startDate`, `endDate`, `party[]`, `createdAt`.
- Active trip persisted separately.
- Cloud restore order: local first, then Firestore if local missing.
- Deleting trip also deletes trip-scoped pack-list storage keys.
- Date utilities:
  - `daysUntil`: clamp at 0.
  - `tripDurationDays`: inclusive range, minimum 1 day.

### Invites / party sync
- Search users by prefix on lowercase name.
- Duplicate pending invite guard (`tripId + inviteeUid`).
- Accept invite updates invitation status and injects invitee into organizer’s trip party if missing.
- Decline invite sets status and removes from incoming list.
- Outgoing accepted invites are synced back into local trip party once.

### Trail/navigation domain
- Canonical trail dataset includes:
  - Route coordinates
  - Waypoints with `distanceFromStart`, type, optional `dangerLevel`, optional permit flag
  - Water sources with availability status
  - Campsites with proximity, permit notes, site counts
  - Elevation profile
- Dangerous crossings list includes Sandy, Muddy Fork, Eliot Branch.
- Position update logic:
  - nearest-route index via sliding search window around last index
  - distance remaining from cumulative route miles
  - next waypoint = first waypoint ahead by `distanceFromStart`
  - current segment inferred by start/end waypoint distances
  - elevation gain from nearest profile point vs start elevation
  - ETA uses 2.0 mph baseline

### Location + safety
- Foreground location permission required.
- Tracking cadence: best navigation accuracy, ~5s / 10m updates.
- SOS behavior:
  - open `tel:911`
  - SMS each emergency contact with last known coordinates
- Emergency contacts persisted locally and mirrored to cloud.
- Proximity alerts:
  - when within 500m of dangerous crossings, create high severity river alert
  - do not duplicate existing crossing alert IDs

### Weather
- Primary source: Open-Meteo Mount Hood endpoint.
- 7-day forecast mapping using WMO code -> description.
- Graceful fallback weather dataset when network/API fails.

### Health/readiness
- iOS-only HealthKit integration.
- 28-day rolling window.
- Readiness factors:
  - weekly miles target 15 mi/wk
  - longest hike target 8 mi
  - elevation target 1,000 ft/month (from flights climbed * 10 ft)
  - consistency target 4/4 active weeks
- Factor status thresholds:
  - `great >= 80`, `ok >= 50`, else `low`
- Weighted score:
  - weekly 0.3, long hike 0.3, elevation 0.2, consistency 0.2
  - if no elevation data, redistribute weights across remaining factors

### Pack planning
- Default gear catalog with categories, weights in ounces, consumable flag.
- Base weight = included non-consumables.
- Food/water estimate = `tripDays * 22oz + 70oz`.
- Total weight = base + food/water.
- Trip days bounded 1...14.
- Pack class badges by base weight:
  - `<10 lb` ultralight
  - `<20 lb` lightweight
  - `<30 lb` traditional
  - `>=30 lb` heavy
- Per-trip persistence keys:
  - included default IDs
  - custom items
  - trip days
  - target ounces
  - edits to default items

### Monetization
- Premium SKU: `com.timberlinetrail.app.premium`.
- Locked tabs when not premium: Navigation, Train, Trips.
- Restore purchases supported.
- Local premium cache + cloud mirror.
- Tester UID bypass exists in blueprint.

## SwiftUI architecture plan

### 1) Foundation (project setup)
- Add folders/modules: `App`, `Core`, `Domain`, `Features`, `Services`, `Data`.
- Set up dependency container (`AppEnvironment`) for service injection.
- Add local persistence layer (`UserDefaults` + file JSON store) and cloud sync adapters.

### 2) Domain + rules parity
- Port all domain models and pure business logic first:
  - trip/date math, readiness computation, pack calculations, waypoint/segment derivation.
- Build these as pure Swift structs/services with unit tests before UI wiring.

### 3) Data providers/services
- Implement service protocols + concrete adapters:
  - `AuthService` (Firebase Auth + Apple Sign In)
  - `UserService` (profile + public user indexing)
  - `TripService` (local-first + Firestore mirror)
  - `InviteService`
  - `LocationService` (CoreLocation)
  - `TrailNavigationService`
  - `SafetyService` (alerts + SOS)
  - `WeatherService` (Open-Meteo + fallback)
  - `HealthService` (HealthKit)
  - `PurchaseService` (StoreKit 2)

### 4) App flow + navigation shell
- Build state machine:
  - `unauthenticated -> onboarding-required -> app-ready`.
- Build `TabView` with premium-gated tabs and paywall flow.

### 5) Feature-by-feature UI implementation
- Order:
  1. Auth + Onboarding + Settings
  2. Trips + Trip Detail + Pack Planner
  3. Map + Navigation + Trail Info
  4. Safety + Emergency + Alerts
  5. Training + Health readiness
  6. Invites + social sync

### 6) Quality gates
- Unit tests for pure rules (readiness, pack, trip date math, trail progress).
- Integration tests for local/cloud merge behavior.
- UI tests for auth flow, premium gating, and critical emergency actions.

## Delivery phases

### Phase 1 (MVP parity)
- Auth/onboarding
- Trips + active trip
- Trail map data rendering
- Basic location tracking + progress metrics
- Settings + auto-lock

### Phase 2 (core differentiators)
- Pack planner full logic
- Safety alerts + SOS + contacts
- Weather integration + fallback
- Health readiness score

### Phase 3 (monetization + collaboration)
- StoreKit premium unlock/restore + tab locks
- Invites + party sync with cloud
- Polish + analytics + app store hardening

## Implementation order in this repo
1. Create domain models + rule engines with tests.
2. Stand up Swift services with mock + live adapters.
3. Replace `ContentView` with root app coordinator and auth/onboarding flow.
4. Add tab shell and implement features in the phase order above.
5. Validate rule parity against this plan before release.

## Progress snapshot (March 6, 2026)
- Completed in code:
  - Phase 1 shell in SwiftUI (`auth -> onboarding -> tab app`) with trips/settings/map baseline.
  - Step 2 service architecture scaffold:
    - Protocols for `AuthService`, `UserService`, `TripService`, `SettingsService`
    - `AppEnvironment` dependency container with local + Firebase-backed adapters
    - `AppStore` refactored to orchestrate via services (local-first + remote sync)
    - Service/store extraction completed into dedicated files:
      - `Timberline Trail App/AppServices.swift`
      - `Timberline Trail App/AppStore.swift`
  - Step 3 app flow routing:
    - Added explicit `AppFlowState` state machine (`unauthenticated`, `onboardingRequired`, `ready`)
    - Added root `AppFlowCoordinatorView` and switched `ContentView` to coordinator-driven routing
- Domain rule utilities added for:
    - Pack math (base, consumables estimate, total, weight class thresholds)
    - Readiness score calculation (with elevation-weight redistribution when elevation is unavailable)
    - Trail progress helpers (route cumulative miles, nearest index, distance remaining, waypoint lookahead, ETA)
- Completed in tests:
  - Unit coverage expanded to validate all rules above plus existing trip/date utilities.
  - Service adapter tests added for local settings + local trip persistence round-trip.
