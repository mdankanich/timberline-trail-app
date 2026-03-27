//
//  AppServices.swift
//  Timberline Trail App
//
//  Created by Michael Dankanich on 3/6/26.
//

import Foundation
import AuthenticationServices

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct TripsSnapshot: Codable, Hashable {
    var trips: [Trip]
    var activeTripID: String?
    var importedTrailData: ImportedTrailData?
}

// MARK: - Trail Sync Models (Step 1 schema foundation)

enum WaypointChangeAction: String, Codable, Hashable {
    case add
    case edit
    case softDelete
}

struct TrailSyncWaypoint: Codable, Hashable, Identifiable {
    var id: String
    var trailId: String
    var name: String
    var type: TrailWaypointType
    var dangerLevel: DangerLevel?
    var summary: String?
    var distanceFromStart: Double
    var latitude: Double
    var longitude: Double
    var seasonTag: String?
    var isDeleted: Bool
    var deletedAt: Date?
    var deletedBy: String?
    var updatedAt: Date
    var updatedByUID: String
    var updatedByEmail: String?
}

struct TrailSyncWaypointChange: Codable, Hashable, Identifiable {
    var id: String
    var trailId: String
    var waypointId: String
    var action: WaypointChangeAction
    var seasonTag: String?
    var actorUID: String
    var actorEmail: String?
    var changedAt: Date
    var clientTimestamp: Date?
    var previousValue: TrailSyncWaypoint?
    var newValue: TrailSyncWaypoint?
}

struct TrailSyncVersion: Codable, Hashable, Identifiable {
    var id: String
    var trailId: String
    var baseVersionId: String?
    var fileName: String
    var gpxHash: String
    var routePointCount: Int
    var waypointCount: Int
    var createdAt: Date
    var createdByUID: String
    var createdByEmail: String?
    var changesSummary: TrailSyncChangesSummary
}

struct TrailSyncChangesSummary: Codable, Hashable {
    var added: Int
    var edited: Int
    var softDeleted: Int
}

struct TrailSyncTrail: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var currentVersionId: String
    var sourceFileName: String
    var sourceGPXHash: String
    var lastSyncedAt: Date
    var updatedAt: Date
    var updatedByUID: String
    var updatedByEmail: String?
}

struct PendingWaypointOperation: Codable, Hashable, Identifiable {
    var id: String
    var trailId: String?
    var waypointId: String
    var action: WaypointChangeAction
    var queuedAt: Date
    var actorEmail: String?
    var payload: TrailSyncWaypoint?
}

enum AppPersistenceKeys {
    static let users = "phase1_users"
    static let session = "phase1_session"
    static let profile = "phase1_profile"
    static let settings = "phase1_settings"
    static let trips = "phase1_trips"
    static let activeTripID = "phase1_active_trip_id"
    static let importedTrail = "phase1_imported_trail"
    static let pendingWaypointOperations = "phase1_pending_waypoint_operations"
}

enum AuthServiceError: LocalizedError, Equatable {
    case invalidCredentials
    case invalidSignup
    case duplicateEmail
    case invalidResetEmail
    case userNotFound
    case appleSignInFailed
    case appleTokenMissing
    case appleNonceMissing

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .invalidSignup:
            return "Enter a valid email and password (6+ chars)."
        case .duplicateEmail:
            return "An account with this email already exists."
        case .invalidResetEmail:
            return "Enter a valid email to reset your password."
        case .userNotFound:
            return "No account found for that email."
        case .appleSignInFailed:
            return "Apple Sign In failed."
        case .appleTokenMissing:
            return "Apple identity token unavailable."
        case .appleNonceMissing:
            return "Missing Apple nonce."
        }
    }
}

protocol AuthService {
    func currentSession() -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String?) async throws -> AuthSession
    func signOut()
    func deleteCurrentUser() async throws
}

protocol SettingsService {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

protocol UserService {
    func loadLocalProfile() -> UserProfile?
    func saveLocalProfile(_ profile: UserProfile?)
    func clearLocalProfile()
    func fetchRemoteProfile() async -> UserProfile?
    func pushRemoteProfile(_ profile: UserProfile) async
    func deleteRemoteProfile() async throws
}

protocol TripService {
    func loadLocalTrips() -> TripsSnapshot
    func saveLocalTrips(_ snapshot: TripsSnapshot)
    func clearLocalTrips()
    func fetchRemoteTrips() async -> TripsSnapshot?
    func pushRemoteTrips(_ snapshot: TripsSnapshot) async
    func deleteRemoteTrips() async throws
}

protocol AppContentService {
    func fetchSafetyContent() async -> SafetyContent?
}

protocol TrailSyncService {
    func findTrailByGPXHash(_ gpxHash: String) async -> TrailSyncTrail?
    func upsertTrailFromImport(imported: ImportedTrailData, gpxHash: String) async -> TrailSyncTrail?
}

enum PersistenceCodec {
    static func persist<T: Encodable>(_ value: T?, key: String, defaults: UserDefaults) {
        if value == nil {
            defaults.removeObject(forKey: key)
            return
        }
        guard let value = value else { return }
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to persist \(key): \(error)")
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

final class LocalAuthService: AuthService {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentSession() -> AuthSession? {
        PersistenceCodec.load(AuthSession.self, key: AppPersistenceKeys.session, defaults: defaults)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }

        let users = PersistenceCodec.load([StoredUser].self, key: AppPersistenceKeys.users, defaults: defaults) ?? []
        guard users.contains(where: { $0.email == normalized && $0.password == password }) else {
            throw AuthServiceError.invalidCredentials
        }

        let session = AuthSession(email: normalized)
        PersistenceCodec.persist(session, key: AppPersistenceKeys.session, defaults: defaults)
        return session
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized.contains("@"), password.count >= 6 else {
            throw AuthServiceError.invalidSignup
        }

        var users = PersistenceCodec.load([StoredUser].self, key: AppPersistenceKeys.users, defaults: defaults) ?? []
        guard !users.contains(where: { $0.email == normalized }) else {
            throw AuthServiceError.duplicateEmail
        }

        users.append(StoredUser(email: normalized, password: password))
        PersistenceCodec.persist(users, key: AppPersistenceKeys.users, defaults: defaults)

        let session = AuthSession(email: normalized)
        PersistenceCodec.persist(session, key: AppPersistenceKeys.session, defaults: defaults)
        return session
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String?) async throws -> AuthSession {
        let email = credential.email ?? "apple-\(credential.user.prefix(8))@timberline.local"
        let session = AuthSession(email: email)
        PersistenceCodec.persist(session, key: AppPersistenceKeys.session, defaults: defaults)
        return session
    }

    func requestPasswordReset(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized.contains("@") else {
            throw AuthServiceError.invalidResetEmail
        }
        let users = PersistenceCodec.load([StoredUser].self, key: AppPersistenceKeys.users, defaults: defaults) ?? []
        guard users.contains(where: { $0.email == normalized }) else {
            throw AuthServiceError.userNotFound
        }
    }

    func signOut() {
        defaults.removeObject(forKey: AppPersistenceKeys.session)
    }

    func deleteCurrentUser() async throws {
        let current = currentSession()
        signOut()

        guard let email = current?.email else { return }
        var users = PersistenceCodec.load([StoredUser].self, key: AppPersistenceKeys.users, defaults: defaults) ?? []
        users.removeAll { $0.email == email }
        PersistenceCodec.persist(users, key: AppPersistenceKeys.users, defaults: defaults)
    }
}

#if canImport(FirebaseAuth)
final class FirebaseAuthService: AuthService {
    func currentSession() -> AuthSession? {
        guard let user = Auth.auth().currentUser else { return nil }
        let email = user.email ?? "firebase-\(user.uid)@timberline.local"
        return AuthSession(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }
        let authResult = try await Auth.auth().signIn(withEmail: normalized, password: password)
        let resolved = authResult.user.email ?? normalized
        return AuthSession(email: resolved)
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized.contains("@"), password.count >= 6 else {
            throw AuthServiceError.invalidSignup
        }
        let authResult = try await Auth.auth().createUser(withEmail: normalized, password: password)
        let resolved = authResult.user.email ?? normalized
        return AuthSession(email: resolved)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String?) async throws -> AuthSession {
        guard let nonce = nonce else { throw AuthServiceError.appleNonceMissing }
        guard
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthServiceError.appleTokenMissing
        }

        let firebaseCredential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: token,
            rawNonce: nonce
        )
        let authResult = try await Auth.auth().signIn(with: firebaseCredential)
        let resolved = authResult.user.email ?? "apple-\(authResult.user.uid)@timberline.local"
        return AuthSession(email: resolved)
    }

    func requestPasswordReset(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized.contains("@") else {
            throw AuthServiceError.invalidResetEmail
        }
        try await Auth.auth().sendPasswordReset(withEmail: normalized)
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }
}
#endif

final class LocalSettingsService: SettingsService {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> AppSettings {
        PersistenceCodec.load(AppSettings.self, key: AppPersistenceKeys.settings, defaults: defaults) ?? .default
    }

    func saveSettings(_ settings: AppSettings) {
        PersistenceCodec.persist(settings, key: AppPersistenceKeys.settings, defaults: defaults)
    }
}

final class LocalUserService: UserService {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLocalProfile() -> UserProfile? {
        PersistenceCodec.load(UserProfile.self, key: AppPersistenceKeys.profile, defaults: defaults)
    }

    func saveLocalProfile(_ profile: UserProfile?) {
        PersistenceCodec.persist(profile, key: AppPersistenceKeys.profile, defaults: defaults)
    }

    func clearLocalProfile() {
        defaults.removeObject(forKey: AppPersistenceKeys.profile)
    }

    func fetchRemoteProfile() async -> UserProfile? { nil }
    func pushRemoteProfile(_ profile: UserProfile) async {}
    func deleteRemoteProfile() async throws {}
}

final class LocalTripService: TripService {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLocalTrips() -> TripsSnapshot {
        let trips = PersistenceCodec.load([Trip].self, key: AppPersistenceKeys.trips, defaults: defaults) ?? []
        var activeTripID = defaults.string(forKey: AppPersistenceKeys.activeTripID)
        if activeTripID == nil {
            activeTripID = trips.first?.id
            defaults.set(activeTripID, forKey: AppPersistenceKeys.activeTripID)
        }
        return TripsSnapshot(trips: trips, activeTripID: activeTripID, importedTrailData: nil)
    }

    func saveLocalTrips(_ snapshot: TripsSnapshot) {
        PersistenceCodec.persist(snapshot.trips, key: AppPersistenceKeys.trips, defaults: defaults)
        defaults.set(snapshot.activeTripID, forKey: AppPersistenceKeys.activeTripID)
    }

    func clearLocalTrips() {
        defaults.removeObject(forKey: AppPersistenceKeys.trips)
        defaults.removeObject(forKey: AppPersistenceKeys.activeTripID)
    }

    func fetchRemoteTrips() async -> TripsSnapshot? { nil }
    func pushRemoteTrips(_ snapshot: TripsSnapshot) async {}
    func deleteRemoteTrips() async throws {}
}

final class LocalAppContentService: AppContentService {
    func fetchSafetyContent() async -> SafetyContent? { nil }
}

final class LocalTrailSyncService: TrailSyncService {
    func findTrailByGPXHash(_ gpxHash: String) async -> TrailSyncTrail? { nil }
    func upsertTrailFromImport(imported: ImportedTrailData, gpxHash: String) async -> TrailSyncTrail? { nil }
}

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
enum FirestoreCodec {
    static func encode<T: Encodable>(_ value: T) -> [String: Any]? {
        guard
            let data = try? JSONEncoder().encode(value),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    static func decode<T: Decodable>(_ data: [String: Any]) -> T? {
        guard
            JSONSerialization.isValidJSONObject(data),
            let jsonData = try? JSONSerialization.data(withJSONObject: data)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: jsonData)
    }
}

final class FirebaseUserCloudService: UserService {
    func loadLocalProfile() -> UserProfile? { nil }
    func saveLocalProfile(_ profile: UserProfile?) {}
    func clearLocalProfile() {}

    func fetchRemoteProfile() async -> UserProfile? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return await withCheckedContinuation { continuation in
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("data")
                .document("profile")
                .getDocument { snap, _ in
                    guard let data = snap?.data() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: FirestoreCodec.decode(data))
                }
        }
    }

    func pushRemoteProfile(_ profile: UserProfile) async {
        guard
            let uid = Auth.auth().currentUser?.uid,
            let encoded = FirestoreCodec.encode(profile)
        else { return }
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("data")
                .document("profile")
                .setData(encoded, merge: true)
        } catch {
            // Keep local state as source of truth when remote sync fails.
        }
    }

    func deleteRemoteProfile() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("data")
            .document("profile")
            .delete()
    }
}

final class FirebaseTripCloudService: TripService {
    func loadLocalTrips() -> TripsSnapshot { TripsSnapshot(trips: [], activeTripID: nil, importedTrailData: nil) }
    func saveLocalTrips(_ snapshot: TripsSnapshot) {}
    func clearLocalTrips() {}

    private struct CloudTripsPayload: Codable {
        var trips: [Trip]
        var activeTripId: String?
        var importedTrailData: ImportedTrailData?
    }

    func fetchRemoteTrips() async -> TripsSnapshot? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return await withCheckedContinuation { continuation in
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("data")
                .document("trips")
                .getDocument { snap, _ in
                    guard
                        let data = snap?.data(),
                        let remote: CloudTripsPayload = FirestoreCodec.decode(data)
                    else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: TripsSnapshot(trips: remote.trips, activeTripID: remote.activeTripId, importedTrailData: remote.importedTrailData))
                }
        }
    }

    func pushRemoteTrips(_ snapshot: TripsSnapshot) async {
        guard
            let uid = Auth.auth().currentUser?.uid,
            let encoded = FirestoreCodec.encode(
                CloudTripsPayload(trips: snapshot.trips, activeTripId: snapshot.activeTripID, importedTrailData: snapshot.importedTrailData)
            )
        else { return }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("data")
                .document("trips")
                .setData(encoded, merge: true)
        } catch {
            // Keep local state as source of truth when remote sync fails.
        }
    }

    func deleteRemoteTrips() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("data")
            .document("trips")
            .delete()
    }
}

final class FirebaseAppContentService: AppContentService {
    func fetchSafetyContent() async -> SafetyContent? {
        await withCheckedContinuation { continuation in
            Firestore.firestore()
                .collection("app_content")
                .document("safety")
                .getDocument { snap, _ in
                    guard
                        let data = snap?.data(),
                        let rows = data["keyNumbers"] as? [[String: Any]]
                    else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let numbers: [SafetyKeyNumber] = rows.compactMap { row in
                        guard
                            let label = row["label"] as? String,
                            let value = row["value"] as? String
                        else { return nil }
                        let id = (row["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedID = (id?.isEmpty == false) ? id! : UUID().uuidString
                        return SafetyKeyNumber(id: resolvedID, label: label, value: value)
                    }

                    continuation.resume(returning: numbers.isEmpty ? nil : SafetyContent(keyNumbers: numbers))
                }
        }
    }
}

final class FirebaseTrailSyncService: TrailSyncService {
    private func actorUID() -> String? { Auth.auth().currentUser?.uid }
    private func actorEmail() -> String? { Auth.auth().currentUser?.email }

    func findTrailByGPXHash(_ gpxHash: String) async -> TrailSyncTrail? {
        do {
            let query = try await Firestore.firestore()
                .collection("trails")
                .whereField("sourceGPXHash", isEqualTo: gpxHash)
                .limit(to: 1)
                .getDocuments()
            guard let document = query.documents.first else { return nil }
            var decoded: TrailSyncTrail? = FirestoreCodec.decode(document.data())
            if decoded?.id.isEmpty ?? true {
                decoded?.id = document.documentID
            }
            return decoded
        } catch {
            return nil
        }
    }

    func upsertTrailFromImport(imported: ImportedTrailData, gpxHash: String) async -> TrailSyncTrail? {
        if let existing = await findTrailByGPXHash(gpxHash) {
            return existing
        }

        guard let uid = actorUID() else { return nil }
        let email = actorEmail()
        let now = Date()
        let trailId = "trail_" + String(gpxHash.prefix(16))
        let versionId = "ver_" + String(UUID().uuidString.prefix(12))
        let summary = TrailSyncChangesSummary(
            added: imported.waypoints.count,
            edited: 0,
            softDeleted: 0
        )
        let trail = TrailSyncTrail(
            id: trailId,
            name: imported.name,
            currentVersionId: versionId,
            sourceFileName: imported.source.fileName,
            sourceGPXHash: gpxHash,
            lastSyncedAt: now,
            updatedAt: now,
            updatedByUID: uid,
            updatedByEmail: email
        )
        let version = TrailSyncVersion(
            id: versionId,
            trailId: trailId,
            baseVersionId: nil,
            fileName: imported.source.fileName,
            gpxHash: gpxHash,
            routePointCount: imported.coordinates.count,
            waypointCount: imported.waypoints.count,
            createdAt: now,
            createdByUID: uid,
            createdByEmail: email,
            changesSummary: summary
        )

        guard
            let trailData = FirestoreCodec.encode(trail),
            let versionData = FirestoreCodec.encode(version)
        else { return nil }

        do {
            let db = Firestore.firestore()
            try await db.collection("trails").document(trailId).setData(trailData, merge: true)
            try await db.collection("trails").document(trailId).collection("versions").document(versionId).setData(versionData, merge: true)

            for waypoint in imported.waypoints {
                guard let latitude = waypoint.latitude, let longitude = waypoint.longitude else { continue }
                let syncWaypoint = TrailSyncWaypoint(
                    id: waypoint.id,
                    trailId: trailId,
                    name: waypoint.name,
                    type: waypoint.type,
                    dangerLevel: waypoint.dangerLevel,
                    summary: waypoint.summary,
                    distanceFromStart: waypoint.distanceFromStart,
                    latitude: latitude,
                    longitude: longitude,
                    seasonTag: nil,
                    isDeleted: false,
                    deletedAt: nil,
                    deletedBy: nil,
                    updatedAt: now,
                    updatedByUID: uid,
                    updatedByEmail: email
                )
                guard let waypointData = FirestoreCodec.encode(syncWaypoint) else { continue }
                try await db.collection("trails").document(trailId).collection("waypoints").document(waypoint.id).setData(waypointData, merge: true)
            }

            return trail
        } catch {
            return nil
        }
    }
}
#endif

final class CompositeUserService: UserService {
    private let local: LocalUserService
    private let remote: UserService?

    init(local: LocalUserService, remote: UserService?) {
        self.local = local
        self.remote = remote
    }

    func loadLocalProfile() -> UserProfile? { local.loadLocalProfile() }
    func saveLocalProfile(_ profile: UserProfile?) { local.saveLocalProfile(profile) }
    func clearLocalProfile() { local.clearLocalProfile() }
    func fetchRemoteProfile() async -> UserProfile? { await remote?.fetchRemoteProfile() }
    func pushRemoteProfile(_ profile: UserProfile) async { await remote?.pushRemoteProfile(profile) }
    func deleteRemoteProfile() async throws { try await remote?.deleteRemoteProfile() }
}

final class CompositeTripService: TripService {
    private let local: LocalTripService
    private let remote: TripService?

    init(local: LocalTripService, remote: TripService?) {
        self.local = local
        self.remote = remote
    }

    func loadLocalTrips() -> TripsSnapshot { local.loadLocalTrips() }
    func saveLocalTrips(_ snapshot: TripsSnapshot) { local.saveLocalTrips(snapshot) }
    func clearLocalTrips() { local.clearLocalTrips() }
    func fetchRemoteTrips() async -> TripsSnapshot? { await remote?.fetchRemoteTrips() }
    func pushRemoteTrips(_ snapshot: TripsSnapshot) async { await remote?.pushRemoteTrips(snapshot) }
    func deleteRemoteTrips() async throws { try await remote?.deleteRemoteTrips() }
}

struct AppEnvironment {
    let authService: AuthService
    let settingsService: SettingsService
    let userService: UserService
    let tripService: TripService
    let appContentService: AppContentService
    let trailSyncService: TrailSyncService
}

extension AppEnvironment {
    static func live(defaults: UserDefaults = .standard) -> AppEnvironment {
        let localSettings = LocalSettingsService(defaults: defaults)
        let localUser = LocalUserService(defaults: defaults)
        let localTrip = LocalTripService(defaults: defaults)

#if canImport(FirebaseAuth)
        let auth: AuthService = FirebaseAuthService()
#else
        let auth: AuthService = LocalAuthService(defaults: defaults)
#endif

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let user: UserService = CompositeUserService(local: localUser, remote: FirebaseUserCloudService())
        let trip: TripService = CompositeTripService(local: localTrip, remote: FirebaseTripCloudService())
        let content: AppContentService = FirebaseAppContentService()
        let trailSync: TrailSyncService = FirebaseTrailSyncService()
#else
        let user: UserService = CompositeUserService(local: localUser, remote: nil)
        let trip: TripService = CompositeTripService(local: localTrip, remote: nil)
        let content: AppContentService = LocalAppContentService()
        let trailSync: TrailSyncService = LocalTrailSyncService()
#endif

        return AppEnvironment(
            authService: auth,
            settingsService: localSettings,
            userService: user,
            tripService: trip,
            appContentService: content,
            trailSyncService: trailSync
        )
    }
}
