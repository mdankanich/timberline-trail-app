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
}

enum AppPersistenceKeys {
    static let users = "phase1_users"
    static let session = "phase1_session"
    static let profile = "phase1_profile"
    static let settings = "phase1_settings"
    static let trips = "phase1_trips"
    static let activeTripID = "phase1_active_trip_id"
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
}

protocol TripService {
    func loadLocalTrips() -> TripsSnapshot
    func saveLocalTrips(_ snapshot: TripsSnapshot)
    func clearLocalTrips()
    func fetchRemoteTrips() async -> TripsSnapshot?
    func pushRemoteTrips(_ snapshot: TripsSnapshot) async
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
        return TripsSnapshot(trips: trips, activeTripID: activeTripID)
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
}

final class FirebaseTripCloudService: TripService {
    func loadLocalTrips() -> TripsSnapshot { TripsSnapshot(trips: [], activeTripID: nil) }
    func saveLocalTrips(_ snapshot: TripsSnapshot) {}
    func clearLocalTrips() {}

    private struct CloudTripsPayload: Codable {
        var trips: [Trip]
        var activeTripId: String?
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
                    continuation.resume(returning: TripsSnapshot(trips: remote.trips, activeTripID: remote.activeTripId))
                }
        }
    }

    func pushRemoteTrips(_ snapshot: TripsSnapshot) async {
        guard
            let uid = Auth.auth().currentUser?.uid,
            let encoded = FirestoreCodec.encode(
                CloudTripsPayload(trips: snapshot.trips, activeTripId: snapshot.activeTripID)
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
}

struct AppEnvironment {
    let authService: AuthService
    let settingsService: SettingsService
    let userService: UserService
    let tripService: TripService
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
#else
        let user: UserService = CompositeUserService(local: localUser, remote: nil)
        let trip: TripService = CompositeTripService(local: localTrip, remote: nil)
#endif

        return AppEnvironment(
            authService: auth,
            settingsService: localSettings,
            userService: user,
            tripService: trip
        )
    }
}
