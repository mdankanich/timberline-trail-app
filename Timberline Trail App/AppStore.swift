//
//  AppStore.swift
//  Timberline Trail App
//
//  Created by Michael Dankanich on 3/6/26.
//

import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import CoreLocation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AppFlowState: Equatable {
    case unauthenticated
    case onboardingRequired
    case ready
}

func deriveAppFlowState(session: AuthSession?, profile: UserProfile?) -> AppFlowState {
    guard session != nil else { return .unauthenticated }
    guard profile != nil else { return .onboardingRequired }
    return .ready
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var settings: AppSettings
    @Published private(set) var trips: [Trip]
    @Published private(set) var activeTripID: String?
    @Published private(set) var authError: String?
    @Published private(set) var authInfoMessage: String?
    @Published private(set) var isAuthLoading: Bool
    @Published private(set) var flowState: AppFlowState
    @Published private(set) var safetyKeyNumbers: [SafetyKeyNumber]
    @Published private(set) var importedTrailData: ImportedTrailData?

    private var backgroundedAt: Date?
    private var currentNonce: String?

    private let authService: AuthService
    private let settingsService: SettingsService
    private let userService: UserService
    private let tripService: TripService
    private let appContentService: AppContentService
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    init(environment: AppEnvironment = .live()) {
        self.authService = environment.authService
        self.settingsService = environment.settingsService
        self.userService = environment.userService
        self.tripService = environment.tripService
        self.appContentService = environment.appContentService

        let initialProfile = environment.userService.loadLocalProfile()
        let initialSession = environment.authService.currentSession()
        self.settings = environment.settingsService.loadSettings()
        self.profile = initialProfile
        self.safetyKeyNumbers = SafetyContent.fallback.keyNumbers
        self.importedTrailData = Self.loadImportedTrail(defaults: defaults)

        let tripSnapshot = environment.tripService.loadLocalTrips()
        self.trips = tripSnapshot.trips
        self.activeTripID = tripSnapshot.activeTripID ?? tripSnapshot.trips.first?.id

        self.session = initialSession
        self.authError = nil
        self.authInfoMessage = nil
        self.isAuthLoading = false
        self.flowState = deriveAppFlowState(session: initialSession, profile: initialProfile)

        if session != nil {
            Task { await refreshFromCloud() }
        }
    }

    var needsOnboarding: Bool {
        flowState == .onboardingRequired
    }

    var activeTrip: Trip? {
        trips.first(where: { $0.id == activeTripID })
    }

    func signIn(email: String, password: String) async {
        guard !isAuthLoading else { return }
        authError = nil
        authInfoMessage = nil
        guard validateAuthInput(email: email, password: password, mode: .signIn) else { return }
        isAuthLoading = true
        defer { isAuthLoading = false }
        do {
            session = try await authService.signIn(email: email, password: password)
            refreshFlowState()
            await refreshFromCloud()
        } catch {
            authError = mapAuthError(error, fallback: "Email or password is incorrect.")
        }
    }

    func signUp(email: String, password: String) async {
        guard !isAuthLoading else { return }
        authError = nil
        authInfoMessage = nil
        guard validateAuthInput(email: email, password: password, mode: .signUp) else { return }
        isAuthLoading = true
        defer { isAuthLoading = false }
        do {
            session = try await authService.signUp(email: email, password: password)
            refreshFlowState()
            await refreshFromCloud()
        } catch {
            authError = mapAuthError(error, fallback: "Unable to create account. Try a different email.")
        }
    }

    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        guard !isAuthLoading else { return }
        authError = nil
        authInfoMessage = nil
        isAuthLoading = true
        defer { isAuthLoading = false }
        switch result {
        case .failure:
            authError = "Apple Sign In failed."
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Apple credential missing."
                return
            }

            do {
                session = try await authService.signInWithApple(credential: credential, nonce: currentNonce)
                refreshFlowState()

                let given = credential.fullName?.givenName ?? ""
                let family = credential.fullName?.familyName ?? ""
                let fullName = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
                if !fullName.isEmpty {
                    let newProfile = UserProfile(name: fullName)
                    profile = newProfile
                    userService.saveLocalProfile(newProfile)
                    await userService.pushRemoteProfile(newProfile)
                }

                await refreshFromCloud()
            } catch {
                authError = mapAuthError(error, fallback: "Apple Sign In failed.")
            }
        }
    }

    func signOut() {
        authService.signOut()
        session = nil
        profile = nil
        safetyKeyNumbers = SafetyContent.fallback.keyNumbers
        trips = []
        activeTripID = nil
        backgroundedAt = nil
        authInfoMessage = nil
        userService.clearLocalProfile()
        tripService.clearLocalTrips()
        refreshFlowState()
    }

    func requestPasswordReset(email: String) async {
        guard !isAuthLoading else { return }
        authError = nil
        authInfoMessage = nil
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.contains("@") else {
            authError = "Enter a valid email address."
            return
        }
        isAuthLoading = true
        defer { isAuthLoading = false }
        do {
            try await authService.requestPasswordReset(email: normalized)
            authInfoMessage = "If an account exists, a reset email has been sent."
        } catch {
            authError = mapAuthError(error, fallback: "Unable to send reset email.")
        }
    }

    func clearAuthMessages() {
        authError = nil
        authInfoMessage = nil
    }

    func completeOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextProfile = UserProfile(name: trimmed)
        profile = nextProfile
        userService.saveLocalProfile(nextProfile)
        Task { await userService.pushRemoteProfile(nextProfile) }
        refreshFlowState()
    }

    func updateProfile(name: String, photoURI: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let next = UserProfile(name: trimmed, photoURI: photoURI ?? profile?.photoURI)
        profile = next
        userService.saveLocalProfile(next)
        Task { await userService.pushRemoteProfile(next) }
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settingsService.saveSettings(newSettings)
    }

    var activeTrailName: String {
        importedTrailData?.name ?? "No GPX trail imported"
    }

    var activeTrailDistanceMiles: Double {
        importedTrailData?.totalDistanceMiles ?? 0
    }

    var activeTrailElevationGainFeet: Int {
        importedTrailData?.totalElevationGainFeet ?? 0
    }

    var activeTrailCoordinates: [TrailCoordinate] {
        importedTrailData?.coordinates ?? []
    }

    var activeTrailWaypoints: [TrailWaypoint] {
        (importedTrailData?.waypoints ?? []).sorted { $0.distanceFromStart < $1.distanceFromStart }
    }

    var activeTrailWaterSources: [WaterSource] {
        guard let imported = importedTrailData else { return [] }
        let fromWaypoints = imported.waypoints
            .filter { $0.type == .water }
            .compactMap { waypoint -> WaterSource? in
                guard let latitude = waypoint.latitude, let longitude = waypoint.longitude else { return nil }
                return WaterSource(
                    id: "water-\(waypoint.id)",
                    name: waypoint.name,
                    latitude: latitude,
                    longitude: longitude,
                    status: .available,
                    seasonalNote: waypoint.summary,
                    distanceFromStart: waypoint.distanceFromStart
                )
            }
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
        return fromWaypoints.isEmpty ? imported.waterSources : fromWaypoints
    }

    var activeTrailCampsites: [Campsite] {
        guard let imported = importedTrailData else { return [] }
        let fromWaypoints = imported.waypoints
            .filter { $0.type == .campsite }
            .compactMap { waypoint -> Campsite? in
                guard let latitude = waypoint.latitude, let longitude = waypoint.longitude else { return nil }
                return Campsite(
                    id: "camp-\(waypoint.id)",
                    name: waypoint.name,
                    latitude: latitude,
                    longitude: longitude,
                    elevationFeet: 0,
                    distanceFromStart: waypoint.distanceFromStart,
                    waterProximity: .moderate,
                    hasBearBox: false,
                    permitNotes: waypoint.summary ?? "Imported GPX campsite",
                    sites: 5
                )
            }
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
        return fromWaypoints.isEmpty ? imported.campsites : fromWaypoints
    }

    var activeTrailSourceLabel: String {
        importedTrailData == nil ? "No Trail Loaded" : "Imported GPX"
    }

    func previewTrailImport(from url: URL) throws -> TrailImportPreview {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let xml = try String(contentsOf: url, encoding: .utf8)
        let imported = try importedTrailDataFromGPX(xml: xml, fileName: url.lastPathComponent)
        return importedTrailPreview(from: imported)
    }

    func importTrail(from url: URL) throws {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let xml = try String(contentsOf: url, encoding: .utf8)
        let imported = try importedTrailDataFromGPX(xml: xml, fileName: url.lastPathComponent)
        importedTrailData = imported
        try Self.persistImportedTrail(imported, fileManager: fileManager, defaults: defaults)
        persistTrips()
    }

    func resetImportedTrail() {
        importedTrailData = nil
        Self.removePersistedImportedTrail(fileManager: fileManager)
        defaults.removeObject(forKey: AppPersistenceKeys.importedTrail)
        persistTrips()
    }

    func canEditWaypoints() -> Bool {
        session != nil && importedTrailData != nil
    }

    func updateWaypoint(
        id: String,
        name: String,
        type: TrailWaypointType,
        dangerLevel: DangerLevel?,
        summary: String?,
        editorName: String
    ) throws {
        guard canEditWaypoints(), var imported = importedTrailData else {
            throw NSError(domain: "TrailImport", code: 20, userInfo: [NSLocalizedDescriptionKey: "Sign in and import a GPX trail before editing waypoints."])
        }
        guard let index = imported.waypoints.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "TrailImport", code: 21, userInfo: [NSLocalizedDescriptionKey: "Waypoint not found."])
        }

        imported.waypoints[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        imported.waypoints[index].type = type
        imported.waypoints[index].dangerLevel = dangerLevel
        let note = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        imported.waypoints[index].summary = (note?.isEmpty == true) ? nil : note
        imported.waypoints[index].lastEditedBy = editorName
        imported.waypoints[index].lastEditedAt = Date()
        imported.waypoints.sort { $0.distanceFromStart < $1.distanceFromStart }

        importedTrailData = imported
        try Self.persistImportedTrail(imported, fileManager: fileManager, defaults: defaults)
        persistTrips()
    }

    func addWaypointAtCurrentLocation(
        name: String,
        type: TrailWaypointType,
        dangerLevel: DangerLevel?,
        summary: String?,
        latitude: Double,
        longitude: Double,
        editorName: String
    ) throws {
        guard canEditWaypoints(), var imported = importedTrailData else {
            throw NSError(domain: "TrailImport", code: 22, userInfo: [NSLocalizedDescriptionKey: "Sign in and import a GPX trail before adding waypoints."])
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "TrailImport", code: 23, userInfo: [NSLocalizedDescriptionKey: "Waypoint name is required."])
        }

        let distanceFromStart = distanceFromStartMiles(
            latitude: latitude,
            longitude: longitude,
            route: imported.coordinates
        )

        let waypoint = TrailWaypoint(
            id: "wpt_" + String(UUID().uuidString.prefix(10)),
            name: trimmedName,
            distanceFromStart: distanceFromStart,
            type: type,
            dangerLevel: dangerLevel,
            summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            lastEditedBy: editorName,
            lastEditedAt: Date()
        )
        imported.waypoints.append(waypoint)
        imported.waypoints.sort { $0.distanceFromStart < $1.distanceFromStart }

        importedTrailData = imported
        try Self.persistImportedTrail(imported, fileManager: fileManager, defaults: defaults)
        persistTrips()
    }

    private static func loadImportedTrail(defaults: UserDefaults) -> ImportedTrailData? {
        let decoder = JSONDecoder()
        if let url = importedTrailFileURL(fileManager: .default),
           let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode(ImportedTrailData.self, from: data) {
            return decoded
        }

        // Legacy fallback for older builds that stored trail JSON in UserDefaults.
        if let legacy = PersistenceCodec.load(ImportedTrailData.self, key: AppPersistenceKeys.importedTrail, defaults: defaults) {
            try? persistImportedTrail(legacy, fileManager: .default, defaults: defaults)
            defaults.removeObject(forKey: AppPersistenceKeys.importedTrail)
            return legacy
        }
        return nil
    }

    private static func persistImportedTrail(_ value: ImportedTrailData, fileManager: FileManager, defaults: UserDefaults) throws {
        guard let url = importedTrailFileURL(fileManager: fileManager) else {
            throw NSError(domain: "TrailImport", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unable to resolve trail storage location."])
        }
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
        defaults.removeObject(forKey: AppPersistenceKeys.importedTrail)
    }

    private static func removePersistedImportedTrail(fileManager: FileManager) {
        guard let url = importedTrailFileURL(fileManager: fileManager),
              fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    private static func importedTrailFileURL(fileManager: FileManager) -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("TimberlineTrail", isDirectory: true)
            .appendingPathComponent("imported-trail.json", isDirectory: false)
    }

    private func distanceFromStartMiles(
        latitude: Double,
        longitude: Double,
        route: [TrailCoordinate]
    ) -> Double {
        guard !route.isEmpty else { return 0 }
        var cumulativeMilesByIndex: [Double] = Array(repeating: 0, count: route.count)
        for i in 1..<route.count {
            let prev = CLLocation(latitude: route[i - 1].latitude, longitude: route[i - 1].longitude)
            let next = CLLocation(latitude: route[i].latitude, longitude: route[i].longitude)
            cumulativeMilesByIndex[i] = cumulativeMilesByIndex[i - 1] + (prev.distance(from: next) / 1609.344)
        }

        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        let current = CLLocation(latitude: latitude, longitude: longitude)
        for (index, point) in route.enumerated() {
            let dist = current.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            if dist < bestDistance {
                bestDistance = dist
                bestIndex = index
            }
        }
        return (cumulativeMilesByIndex[bestIndex] * 100).rounded() / 100
    }

    func createTrip(name: String, startDate: Date, endDate: Date) {
        let trip = Trip(
            id: "trip_" + String(UUID().uuidString.prefix(8)),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: formatYMD(startDate),
            endDate: formatYMD(endDate),
            partyCount: 1,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        trips.append(trip)
        if activeTripID == nil {
            activeTripID = trip.id
        }
        persistTrips()
    }

    func updateTrip(id: String, name: String, startDate: Date, endDate: Date) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        trips[index].startDate = formatYMD(startDate)
        trips[index].endDate = formatYMD(endDate)
        persistTrips()
    }

    func setActiveTrip(id: String) {
        activeTripID = id
        persistTrips()
    }

    func deleteTrip(id: String) {
        trips.removeAll(where: { $0.id == id })
        if activeTripID == id {
            activeTripID = trips.first?.id
        }
        persistTrips()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            backgroundedAt = Date()
        case .active:
            guard settings.autoLockEnabled, let backgroundedAt = backgroundedAt else { return }
            let elapsed = Date().timeIntervalSince(backgroundedAt)
            if elapsed >= Double(settings.autoLockMinutes.rawValue * 60), session != nil {
                signOut()
            }
            self.backgroundedAt = nil
        @unknown default:
            break
        }
    }

    private func persistTrips() {
        let snapshot = TripsSnapshot(trips: trips, activeTripID: activeTripID, importedTrailData: importedTrailData)
        tripService.saveLocalTrips(snapshot)
        Task { await tripService.pushRemoteTrips(snapshot) }
    }

    private func refreshFromCloud() async {
        if let remoteProfile = await userService.fetchRemoteProfile() {
            profile = remoteProfile
            userService.saveLocalProfile(remoteProfile)
        }
        if let remoteTrips = await tripService.fetchRemoteTrips() {
            trips = remoteTrips.trips
            activeTripID = remoteTrips.activeTripID ?? remoteTrips.trips.first?.id
            if let remoteTrail = remoteTrips.importedTrailData {
                importedTrailData = remoteTrail
                try? Self.persistImportedTrail(remoteTrail, fileManager: fileManager, defaults: defaults)
            }
            tripService.saveLocalTrips(TripsSnapshot(trips: trips, activeTripID: activeTripID, importedTrailData: importedTrailData))
        }
        if let safetyContent = await appContentService.fetchSafetyContent() {
            safetyKeyNumbers = safetyContent.keyNumbers
        } else {
            safetyKeyNumbers = SafetyContent.fallback.keyNumbers
        }
        refreshFlowState()
    }

    private func refreshFlowState() {
        flowState = deriveAppFlowState(session: session, profile: profile)
    }

    private func formatYMD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private enum AuthMode {
        case signIn
        case signUp
    }

    private func validateAuthInput(email: String, password: String, mode: AuthMode) -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, normalizedEmail.contains("@") else {
            authError = "Enter a valid email address."
            return false
        }

        guard !password.isEmpty else {
            authError = "Enter your password."
            return false
        }

        if mode == .signUp, password.count < 6 {
            authError = "Password must be at least 6 characters."
            return false
        }
        return true
    }

    private func mapAuthError(_ error: Error, fallback: String) -> String {
        if let message = (error as? LocalizedError)?.errorDescription {
            return message
        }
#if canImport(FirebaseAuth)
        let nsError = error as NSError
        guard let code = AuthErrorCode.Code(rawValue: nsError.code) else {
            return fallback
        }

        switch code {
        case .wrongPassword, .invalidCredential, .invalidEmail, .userNotFound:
            return "Email or password is incorrect."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .networkError:
            return "Network error. Check your internet and try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait and try again."
        default:
            return fallback
        }
#else
        return fallback
#endif
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randomBytes: [UInt8] = Array(repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            randomBytes.forEach { random in
                if remaining == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }

        return result
    }
}
