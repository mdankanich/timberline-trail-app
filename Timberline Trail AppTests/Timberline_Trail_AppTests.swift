//
//  Timberline_Trail_AppTests.swift
//  Timberline Trail AppTests
//
//  Created by Michael Dankanich on 3/5/26.
//

import XCTest
import CoreLocation
@testable import Timberline_Trail_App

class Timberline_Trail_AppTests: XCTestCase {

    func testDaysUntilClampsToZero() throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!
        XCTAssertEqual(daysUntil("2026-03-01", now: now), 0)
        XCTAssertEqual(daysUntil(nil, now: now), 0)
    }

    func testTripDurationIsInclusive() throws {
        XCTAssertEqual(tripDurationDays(start: "2026-08-01", end: "2026-08-05"), 5)
        XCTAssertEqual(tripDurationDays(start: "2026-08-01", end: "2026-08-01"), 1)
    }

    func testFormatDateRangeContainsYear() throws {
        let text = formatDateRange(start: "2026-08-01", end: "2026-08-05")
        XCTAssertTrue(text.contains("2026"))
    }

    func testPackWeightRules() throws {
        let items: [PackItem] = [
            PackItem(id: "tent", name: "Tent", weightOz: 32, consumable: false, isIncluded: true),
            PackItem(id: "snack", name: "Snacks", weightOz: 12, consumable: true, isIncluded: true),
            PackItem(id: "stove", name: "Stove", weightOz: 9, consumable: false, isIncluded: false),
        ]

        let base = calculateBaseWeightOz(items: items)
        XCTAssertEqual(base, 32, accuracy: 0.001)
        XCTAssertEqual(estimateFoodAndWaterWeightOz(tripDays: 0), 92, accuracy: 0.001)
        XCTAssertEqual(estimateFoodAndWaterWeightOz(tripDays: 20), 378, accuracy: 0.001)
        XCTAssertEqual(calculateTotalPackWeightOz(baseWeightOz: base, tripDays: 3), 168, accuracy: 0.001)
    }

    func testPackClassThresholds() throws {
        XCTAssertEqual(packClass(forBaseWeightOz: 9.9 * 16), .ultralight)
        XCTAssertEqual(packClass(forBaseWeightOz: 10.0 * 16), .lightweight)
        XCTAssertEqual(packClass(forBaseWeightOz: 20.0 * 16), .traditional)
        XCTAssertEqual(packClass(forBaseWeightOz: 30.0 * 16), .heavy)
    }

    func testReadinessWeightsWithAndWithoutElevation() throws {
        let withElevation = computeReadinessScore(
            weeklyMiles: 15,
            longestHikeMiles: 8,
            elevationGainFeet: 1000,
            activeWeeksInLastFour: 4
        )
        XCTAssertEqual(withElevation.score, 100)
        XCTAssertEqual(readinessStatus(for: withElevation.score), .great)

        let withoutElevation = computeReadinessScore(
            weeklyMiles: 7.5,
            longestHikeMiles: 4,
            elevationGainFeet: nil,
            activeWeeksInLastFour: 2
        )
        XCTAssertNil(withoutElevation.elevationScore)
        XCTAssertEqual(withoutElevation.score, 50)
        XCTAssertEqual(readinessStatus(for: withoutElevation.score), .ok)
    }

    func testTrailProgressUtilities() throws {
        let route = [
            TrailCoordinate(latitude: 45.0000, longitude: -121.0000),
            TrailCoordinate(latitude: 45.0010, longitude: -121.0000),
            TrailCoordinate(latitude: 45.0020, longitude: -121.0000),
            TrailCoordinate(latitude: 45.0030, longitude: -121.0000),
        ]
        let user = CLLocationCoordinate2D(latitude: 45.0011, longitude: -121.0000)
        let nearest = nearestRouteIndex(route: route, userLocation: user, lastIndex: 0, windowRadius: 2)
        XCTAssertEqual(nearest, 1)

        let remaining = distanceRemainingMiles(route: route, nearestIndex: nearest)
        XCTAssertGreaterThan(remaining, 0)
        XCTAssertEqual(etaHours(distanceRemainingMiles: remaining), remaining / 2.0, accuracy: 0.0001)

        let waypoints = [
            TrailWaypoint(id: "a", name: "Start", distanceFromStart: 0),
            TrailWaypoint(id: "b", name: "Camp", distanceFromStart: 5),
            TrailWaypoint(id: "c", name: "Finish", distanceFromStart: 10),
        ]
        XCTAssertEqual(nextWaypoint(distanceFromStartMiles: 4.9, waypoints: waypoints)?.id, "b")
        XCTAssertEqual(nextWaypoint(distanceFromStartMiles: 10.0, waypoints: waypoints)?.id, nil)
    }

    func testLocalSettingsServiceRoundTrip() throws {
        let suite = "test.settings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create test defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = LocalSettingsService(defaults: defaults)
        var updated = AppSettings.default
        updated.mapType = .terrain
        updated.autoLockEnabled = true
        updated.autoLockMinutes = .five

        service.saveSettings(updated)
        let loaded = service.loadSettings()
        XCTAssertEqual(loaded, updated)
    }

    func testLocalTripServicePersistsSnapshot() throws {
        let suite = "test.trips.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create test defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = LocalTripService(defaults: defaults)
        let snapshot = TripsSnapshot(
            trips: [
                Trip(
                    id: "trip_1",
                    name: "Test Trip",
                    startDate: "2026-08-01",
                    endDate: "2026-08-02",
                    partyCount: 1,
                    createdAt: "2026-03-06T00:00:00Z"
                )
            ],
            activeTripID: "trip_1"
        )

        service.saveLocalTrips(snapshot)
        let loaded = service.loadLocalTrips()
        XCTAssertEqual(loaded, snapshot)
    }

    func testAppFlowStateDerivation() throws {
        XCTAssertEqual(deriveAppFlowState(session: nil, profile: nil), .unauthenticated)
        XCTAssertEqual(
            deriveAppFlowState(session: AuthSession(email: "hiker@example.com"), profile: nil),
            .onboardingRequired
        )
        XCTAssertEqual(
            deriveAppFlowState(
                session: AuthSession(email: "hiker@example.com"),
                profile: UserProfile(name: "Hiker")
            ),
            .ready
        )
    }

    func testLocalAuthPasswordResetSuccess() async throws {
        let suite = "test.auth.reset.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create test defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let auth = LocalAuthService(defaults: defaults)
        _ = try await auth.signUp(email: "reset@example.com", password: "password123")
        try await auth.requestPasswordReset(email: "reset@example.com")
    }

    func testLocalAuthPasswordResetUnknownUserFails() async throws {
        let suite = "test.auth.reset.missing.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create test defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let auth = LocalAuthService(defaults: defaults)
        do {
            try await auth.requestPasswordReset(email: "missing@example.com")
            XCTFail("Expected reset to fail for unknown user")
        } catch let error as AuthServiceError {
            XCTAssertEqual(error, .userNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNormalizeSeasonTagForMigration() throws {
        XCTAssertNil(normalizeSeasonTagForMigration(nil))
        XCTAssertNil(normalizeSeasonTagForMigration("   "))
        XCTAssertEqual(normalizeSeasonTagForMigration("  summer  "), "summer")
    }

    func testMigratePendingWaypointOperationV1BackfillsLegacyFields() throws {
        let queuedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let now = Date(timeIntervalSince1970: 1_700_000_500)
        let original = PendingWaypointOperation(
            id: "op_1",
            mutationID: nil,
            trailId: "trail_1",
            waypointId: "wp_1",
            action: .edit,
            queuedAt: queuedAt,
            actorEmail: "hiker@example.com",
            payload: nil,
            retryCount: 2,
            nextAttemptAt: nil,
            lastAttemptAt: nil,
            lastError: nil
        )

        let migrated = migratePendingWaypointOperationV1(original, now: now, mutationIDGenerator: { "mut_fixed" })
        XCTAssertEqual(migrated.mutationID, "mut_fixed")
        XCTAssertEqual(migrated.retryCount, 2)
        XCTAssertEqual(migrated.lastAttemptAt, queuedAt)
        XCTAssertEqual(migrated.nextAttemptAt, now)
        XCTAssertEqual(migrated.lastError, "Recovered legacy retry metadata")
    }

    func testSanitizeSyncTelemetryEventsV1FiltersAndCaps() throws {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let validEvents = (0..<125).map { index in
            SyncTelemetryEvent(
                id: "e\(index)",
                type: .enqueue,
                createdAt: baseDate.addingTimeInterval(Double(index)),
                details: "event-\(index)"
            )
        }
        let dirtyEvent = SyncTelemetryEvent(id: "blank", type: .flushSkipped, createdAt: baseDate, details: "   ")
        let result = sanitizeSyncTelemetryEventsV1(validEvents + [dirtyEvent], maxCount: 120)

        XCTAssertEqual(result.count, 120)
        XCTAssertEqual(result.first?.id, "e5")
        XCTAssertEqual(result.last?.id, "e124")
        XCTAssertFalse(result.contains(where: { $0.id == "blank" }))
    }

    func testDuePendingWaypointOperationsHonorsRetryTimeAndLimit() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dueA = PendingWaypointOperation(
            id: "a", mutationID: "m1", trailId: nil, waypointId: "w1", action: .add,
            queuedAt: now, actorEmail: nil, payload: nil, retryCount: 0, nextAttemptAt: nil, lastAttemptAt: nil, lastError: nil
        )
        let dueB = PendingWaypointOperation(
            id: "b", mutationID: "m2", trailId: nil, waypointId: "w2", action: .edit,
            queuedAt: now, actorEmail: nil, payload: nil, retryCount: 1, nextAttemptAt: now, lastAttemptAt: nil, lastError: nil
        )
        let notDue = PendingWaypointOperation(
            id: "c", mutationID: "m3", trailId: nil, waypointId: "w3", action: .edit,
            queuedAt: now, actorEmail: nil, payload: nil, retryCount: 1, nextAttemptAt: now.addingTimeInterval(60), lastAttemptAt: nil, lastError: nil
        )

        let due = duePendingWaypointOperations([dueA, dueB, notDue], now: now, limit: 1)
        XCTAssertEqual(due.map(\.id), ["a"])
    }

    func testRetryBackoffIntervalBoundsAndCap() throws {
        XCTAssertEqual(retryBackoffInterval(attempt: 1, jitter: 0), 5, accuracy: 0.001)
        XCTAssertEqual(retryBackoffInterval(attempt: 1, jitter: 9), 8, accuracy: 0.001)
        XCTAssertEqual(retryBackoffInterval(attempt: 8, jitter: 3), 643, accuracy: 0.001)
        XCTAssertEqual(retryBackoffInterval(attempt: 99, jitter: 3), 643, accuracy: 0.001)
    }

    func testShouldShowTrailUpdateRespectsDismissedVersion() throws {
        XCTAssertTrue(shouldShowTrailUpdate(versionId: "v2", dismissedVersion: nil))
        XCTAssertTrue(shouldShowTrailUpdate(versionId: "v2", dismissedVersion: "v1"))
        XCTAssertFalse(shouldShowTrailUpdate(versionId: "v2", dismissedVersion: "v2"))
    }
}
