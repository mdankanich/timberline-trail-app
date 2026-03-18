//
//  ContentView.swift
//  Timberline Trail App
//
//  Created by Michael Dankanich on 3/5/26.
//

import SwiftUI
import MapKit
import CoreLocation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Domain

struct Trip: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var startDate: String // YYYY-MM-DD
    var endDate: String   // YYYY-MM-DD
    var partyCount: Int
    let createdAt: String
}

struct UserProfile: Codable, Hashable {
    var name: String
    var photoURI: String? = nil
}

struct AuthSession: Codable, Hashable {
    var email: String
}

struct StoredUser: Codable, Hashable {
    var email: String
    var password: String
}

struct AppSettings: Codable, Hashable {
    var appearance: AppearanceMode
    var units: Units
    var mapType: MapType
    var gpsInterval: GPSInterval
    var autoLockEnabled: Bool
    var autoLockMinutes: AutoLockMinutes

    static let `default` = AppSettings(
        appearance: .system,
        units: .imperial,
        mapType: .standard,
        gpsInterval: .ten,
        autoLockEnabled: false,
        autoLockMinutes: .fifteen
    )
}

enum Units: String, Codable, CaseIterable, Identifiable {
    case imperial
    case metric
    var id: String { rawValue }
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    var id: String { rawValue }
}

enum MapType: String, Codable, CaseIterable, Identifiable {
    case standard
    case satellite
    case terrain
    var id: String { rawValue }
}

enum GPSInterval: Int, Codable, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case thirty = 30
    var id: Int { rawValue }
}

enum AutoLockMinutes: Int, Codable, CaseIterable, Identifiable {
    case five = 5
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    var id: Int { rawValue }
}

struct TrailCoordinate: Identifiable, Hashable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
}

struct TrackPoint: Identifiable, Codable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct TrackingSession: Identifiable, Codable, Hashable {
    let id: String
    let startedAt: Date
    var endedAt: Date?
    var points: [TrackPoint]
}

struct PackItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var weightOz: Double
    var consumable: Bool
    var isIncluded: Bool
}

let defaultTripPackItems: [PackItem] = [
    PackItem(id: "pack-01", name: "Backpack (50L)", weightOz: 48, consumable: false, isIncluded: true),
    PackItem(id: "shelter-01", name: "Tent (2-person)", weightOz: 48, consumable: false, isIncluded: true),
    PackItem(id: "sleep-01", name: "Sleeping bag (20F)", weightOz: 32, consumable: false, isIncluded: true),
    PackItem(id: "sleep-02", name: "Inflatable pad", weightOz: 16, consumable: false, isIncluded: true),
    PackItem(id: "safety-01", name: "First aid kit", weightOz: 8, consumable: false, isIncluded: true),
    PackItem(id: "nav-01", name: "Satellite communicator", weightOz: 3.5, consumable: false, isIncluded: true),
    PackItem(id: "water-01", name: "Water filter", weightOz: 3, consumable: false, isIncluded: true),
    PackItem(id: "cook-01", name: "Backpacking stove", weightOz: 3, consumable: false, isIncluded: true),
    PackItem(id: "cook-02", name: "Fuel canister", weightOz: 4, consumable: true, isIncluded: true),
    PackItem(id: "food-01", name: "Trail food carry", weightOz: 22, consumable: true, isIncluded: true),
]

enum PackClass: String, Codable, Hashable {
    case ultralight
    case lightweight
    case traditional
    case heavy
}

enum ReadinessStatus: String, Codable, Hashable {
    case great
    case ok
    case low
}

struct ReadinessBreakdown: Codable, Hashable {
    var score: Int
    var weeklyMilesScore: Int
    var longestHikeScore: Int
    var elevationScore: Int?
    var consistencyScore: Int
}

struct TrailWaypoint: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var distanceFromStart: Double
    var type: TrailWaypointType = .waypoint
    var dangerLevel: DangerLevel?
    var summary: String?
}

enum TrailWaypointType: String, Codable, Hashable {
    case trailhead
    case campsite
    case water
    case viewpoint
    case junction
    case crossing
    case shelter
    case waypoint
}

enum DangerLevel: String, Codable, Hashable {
    case low
    case medium
    case high
}

enum WaterSourceStatus: String, Codable, Hashable {
    case available
    case seasonal
    case unavailable
}

enum WaterProximity: String, Codable, Hashable {
    case close
    case moderate
    case far
}

struct WaterSource: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let status: WaterSourceStatus
    let seasonalNote: String?
    let distanceFromStart: Double
}

struct Campsite: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let elevationFeet: Int
    let distanceFromStart: Double
    let waterProximity: WaterProximity
    let hasBearBox: Bool
    let permitNotes: String
    let sites: Int
}

struct EmergencyContact: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var phone: String
    var relationship: String
    var isPrimary: Bool
}

struct SafetyKeyNumber: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let value: String
}

struct SafetyContent: Codable, Hashable {
    let keyNumbers: [SafetyKeyNumber]

    static let fallback = SafetyContent(
        keyNumbers: [
            SafetyKeyNumber(id: "mt-hood-ranger", label: "Mt Hood National Forest Ranger", value: "5036681700"),
            SafetyKeyNumber(id: "hood-river-sheriff", label: "Hood River County Sheriff", value: "5413862098"),
            SafetyKeyNumber(id: "oregon-state-police", label: "Oregon State Police", value: "5413952424"),
            SafetyKeyNumber(id: "clackamas-sar", label: "Search & Rescue (Clackamas Co)", value: "5036558211"),
            SafetyKeyNumber(id: "poison-control", label: "Poison Control", value: "18002221222")
        ]
    )
}

struct WeatherDay: Identifiable, Codable, Hashable {
    let id: String
    let date: String
    let highC: Double
    let lowC: Double
    let description: String
    let precipitationChance: Int
}

struct WeatherSnapshot: Codable, Hashable {
    let temperatureC: Double
    let description: String
    let windKmh: Double
    let humidity: Int
    let sunrise: String
    let sunset: String
    let forecast: [WeatherDay]
    let updatedAt: Date
}

let timberlineTrailCoordinates: [TrailCoordinate] = [
    TrailCoordinate(latitude: 45.3731, longitude: -121.6959),
    TrailCoordinate(latitude: 45.3900, longitude: -121.7250),
    TrailCoordinate(latitude: 45.3830, longitude: -121.7440),
    TrailCoordinate(latitude: 45.4010, longitude: -121.7760),
    TrailCoordinate(latitude: 45.4150, longitude: -121.7850),
    TrailCoordinate(latitude: 45.4280, longitude: -121.7720),
    TrailCoordinate(latitude: 45.4310, longitude: -121.7300),
    TrailCoordinate(latitude: 45.4080, longitude: -121.6569),
    TrailCoordinate(latitude: 45.3898, longitude: -121.6764),
    TrailCoordinate(latitude: 45.3840, longitude: -121.6680),
    TrailCoordinate(latitude: 45.3731, longitude: -121.6959),
]

let timberlineTrailWaypoints: [TrailWaypoint] = [
    TrailWaypoint(id: "timberline-lodge", name: "Timberline Lodge", distanceFromStart: 0.0, type: .trailhead, summary: "Historic lodge and primary trailhead"),
    TrailWaypoint(id: "paradise-park-camp", name: "Paradise Park Camp", distanceFromStart: 3.5, type: .campsite, summary: "Alpine meadow camp"),
    TrailWaypoint(id: "sandy-river-crossing", name: "Sandy River Crossing", distanceFromStart: 7.2, type: .crossing, dangerLevel: .high, summary: "Dangerous glacial river ford"),
    TrailWaypoint(id: "ramona-falls", name: "Ramona Falls", distanceFromStart: 8.5, type: .viewpoint, summary: "Waterfall viewpoint"),
    TrailWaypoint(id: "muddy-fork-crossing", name: "Muddy Fork Crossing", distanceFromStart: 13.3, type: .crossing, dangerLevel: .high, summary: "Braided glacial channels"),
    TrailWaypoint(id: "cairn-basin", name: "Cairn Basin Camp", distanceFromStart: 16.8, type: .campsite),
    TrailWaypoint(id: "elk-cove", name: "Elk Cove Camp", distanceFromStart: 19.2, type: .campsite),
    TrailWaypoint(id: "cloud-cap", name: "Cloud Cap Inn", distanceFromStart: 26.5, type: .shelter),
    TrailWaypoint(id: "eliot-branch-crossing", name: "Eliot Branch Crossing", distanceFromStart: 27.8, type: .crossing, dangerLevel: .high, summary: "Cross before noon; flow rises quickly"),
    TrailWaypoint(id: "cooper-spur-junction", name: "Cooper Spur Junction", distanceFromStart: 30.2, type: .junction),
    TrailWaypoint(id: "umbrella-falls", name: "Umbrella Falls", distanceFromStart: 35.8, type: .water),
    TrailWaypoint(id: "timberline-lodge-end", name: "Timberline Lodge (End)", distanceFromStart: 40.7, type: .trailhead)
]

let timberlineWaterSources: [WaterSource] = [
    WaterSource(id: "water-paradise-park", name: "Paradise Park Spring", latitude: 45.3895, longitude: -121.7260, status: .available, seasonalNote: nil, distanceFromStart: 3.4),
    WaterSource(id: "water-sandy-river", name: "Sandy River", latitude: 45.3830, longitude: -121.7440, status: .available, seasonalNote: "Glacial silt - filter required", distanceFromStart: 7.2),
    WaterSource(id: "water-ramona-falls", name: "Ramona Falls Stream", latitude: 45.3860, longitude: -121.7570, status: .available, seasonalNote: nil, distanceFromStart: 8.5),
    WaterSource(id: "water-cairn-basin", name: "Cairn Basin Spring", latitude: 45.4155, longitude: -121.7855, status: .available, seasonalNote: nil, distanceFromStart: 16.9),
    WaterSource(id: "water-elk-cove", name: "Elk Cove Creek", latitude: 45.4280, longitude: -121.7730, status: .available, seasonalNote: nil, distanceFromStart: 19.2),
    WaterSource(id: "water-umbrella-falls", name: "Umbrella Falls", latitude: 45.3840, longitude: -121.6680, status: .available, seasonalNote: nil, distanceFromStart: 35.8),
]

let timberlineCampsites: [Campsite] = [
    Campsite(id: "camp-paradise-park", name: "Paradise Park", latitude: 45.3900, longitude: -121.7250, elevationFeet: 6188, distanceFromStart: 3.5, waterProximity: .close, hasBearBox: false, permitNotes: "Self-issue at TL", sites: 8),
    Campsite(id: "camp-ramona-falls", name: "Ramona Falls", latitude: 45.3862, longitude: -121.7565, elevationFeet: 3600, distanceFromStart: 8.5, waterProximity: .close, hasBearBox: false, permitNotes: "Self-issue at TL", sites: 6),
    Campsite(id: "camp-cairn-basin", name: "Cairn Basin", latitude: 45.4150, longitude: -121.7850, elevationFeet: 5400, distanceFromStart: 16.8, waterProximity: .close, hasBearBox: false, permitNotes: "NW Forest Pass area", sites: 10),
    Campsite(id: "camp-eden-park", name: "Eden Park", latitude: 45.4130, longitude: -121.7910, elevationFeet: 5000, distanceFromStart: 15.5, waterProximity: .moderate, hasBearBox: false, permitNotes: "Self-issue", sites: 5),
    Campsite(id: "camp-elk-cove", name: "Elk Cove", latitude: 45.4280, longitude: -121.7720, elevationFeet: 4500, distanceFromStart: 19.2, waterProximity: .close, hasBearBox: true, permitNotes: "Required June-Sept via Recreation.gov", sites: 12),
    Campsite(id: "camp-cloud-cap", name: "Cloud Cap", latitude: 45.4080, longitude: -121.6569, elevationFeet: 5940, distanceFromStart: 26.5, waterProximity: .far, hasBearBox: false, permitNotes: "Road access - emergency use", sites: 4),
    Campsite(id: "camp-newton-clark", name: "Newton-Clark", latitude: 45.3880, longitude: -121.6620, elevationFeet: 5000, distanceFromStart: 33.5, waterProximity: .moderate, hasBearBox: false, permitNotes: "Self-issue", sites: 6),
    Campsite(id: "camp-umbrella-falls", name: "Umbrella Falls", latitude: 45.3840, longitude: -121.6680, elevationFeet: 4500, distanceFromStart: 35.8, waterProximity: .close, hasBearBox: false, permitNotes: "Self-issue at TL", sites: 8),
]

let dangerousCrossingWaypointIDs: Set<String> = [
    "sandy-river-crossing",
    "muddy-fork-crossing",
    "eliot-branch-crossing",
]

func daysUntil(_ isoDate: String?, now: Date = Date()) -> Int {
    guard let isoDate = isoDate else { return 0 }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"

    guard let target = formatter.date(from: isoDate) else { return 0 }
    let delta = target.timeIntervalSince(now)
    let days = Int(ceil(delta / 86_400))
    return max(0, days)
}

func tripDurationDays(start: String, end: String) -> Int {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"

    guard
        let startDate = formatter.date(from: start),
        let endDate = formatter.date(from: end)
    else {
        return 1
    }

    let raw = Int(round(endDate.timeIntervalSince(startDate) / 86_400)) + 1
    return max(1, raw)
}

func formatDateRange(start: String, end: String) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"

    guard
        let startDate = formatter.date(from: start),
        let endDate = formatter.date(from: end)
    else {
        return "\(start) - \(end)"
    }

    let short = DateFormatter()
    short.locale = Locale(identifier: "en_US_POSIX")
    short.dateFormat = "MMM d"
    let year = Calendar.current.component(.year, from: startDate)
    return "\(short.string(from: startDate)) - \(short.string(from: endDate)), \(year)"
}

func boundedTripDays(_ value: Int) -> Int {
    min(14, max(1, value))
}

func estimateFoodAndWaterWeightOz(tripDays: Int) -> Double {
    let days = boundedTripDays(tripDays)
    return Double(days * 22 + 70)
}

func calculateBaseWeightOz(items: [PackItem]) -> Double {
    items
        .filter { $0.isIncluded && !$0.consumable }
        .reduce(0) { $0 + max(0, $1.weightOz) }
}

func calculateTotalPackWeightOz(baseWeightOz: Double, tripDays: Int) -> Double {
    max(0, baseWeightOz) + estimateFoodAndWaterWeightOz(tripDays: tripDays)
}

func packClass(forBaseWeightOz weightOz: Double) -> PackClass {
    let pounds = weightOz / 16.0
    if pounds < 10 { return .ultralight }
    if pounds < 20 { return .lightweight }
    if pounds < 30 { return .traditional }
    return .heavy
}

func readinessStatus(for score: Int) -> ReadinessStatus {
    if score >= 80 { return .great }
    if score >= 50 { return .ok }
    return .low
}

func computeReadinessScore(
    weeklyMiles: Double,
    longestHikeMiles: Double,
    elevationGainFeet: Double?,
    activeWeeksInLastFour: Int
) -> ReadinessBreakdown {
    let weeklyScore = Int(min(100, max(0, (weeklyMiles / 15.0) * 100.0)).rounded())
    let longestScore = Int(min(100, max(0, (longestHikeMiles / 8.0) * 100.0)).rounded())
    let consistencyScore = Int(min(100, max(0, (Double(activeWeeksInLastFour) / 4.0) * 100.0)).rounded())

    let elevationRawScore: Int? = elevationGainFeet.map {
        Int(min(100, max(0, ($0 / 1000.0) * 100.0)).rounded())
    }

    let weightedScore: Double
    if let elevationScore = elevationRawScore {
        weightedScore =
            Double(weeklyScore) * 0.3 +
            Double(longestScore) * 0.3 +
            Double(elevationScore) * 0.2 +
            Double(consistencyScore) * 0.2
    } else {
        let total = 0.3 + 0.3 + 0.2
        weightedScore =
            (Double(weeklyScore) * 0.3 / total) +
            (Double(longestScore) * 0.3 / total) +
            (Double(consistencyScore) * 0.2 / total)
    }

    return ReadinessBreakdown(
        score: Int(weightedScore.rounded()),
        weeklyMilesScore: weeklyScore,
        longestHikeScore: longestScore,
        elevationScore: elevationRawScore,
        consistencyScore: consistencyScore
    )
}

func milesBetween(_ lhs: TrailCoordinate, _ rhs: TrailCoordinate) -> Double {
    let earthRadiusMiles = 3958.7613
    let lat1 = lhs.latitude * .pi / 180
    let lon1 = lhs.longitude * .pi / 180
    let lat2 = rhs.latitude * .pi / 180
    let lon2 = rhs.longitude * .pi / 180

    let dLat = lat2 - lat1
    let dLon = lon2 - lon1
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    return earthRadiusMiles * c
}

func cumulativeRouteMiles(route: [TrailCoordinate]) -> [Double] {
    guard !route.isEmpty else { return [] }
    var result: [Double] = [0]
    for index in 1..<route.count {
        let segment = milesBetween(route[index - 1], route[index])
        result.append(result[index - 1] + segment)
    }
    return result
}

func nearestRouteIndex(
    route: [TrailCoordinate],
    userLocation: CLLocationCoordinate2D,
    lastIndex: Int?,
    windowRadius: Int = 25
) -> Int {
    guard !route.isEmpty else { return 0 }
    let center = min(max(lastIndex ?? 0, 0), route.count - 1)
    let start = max(0, center - windowRadius)
    let end = min(route.count - 1, center + windowRadius)

    var bestIndex = center
    var bestDistance = Double.greatestFiniteMagnitude

    for index in start...end {
        let point = route[index]
        let dx = point.latitude - userLocation.latitude
        let dy = point.longitude - userLocation.longitude
        let distance = dx * dx + dy * dy
        if distance < bestDistance {
            bestDistance = distance
            bestIndex = index
        }
    }

    return bestIndex
}

func distanceRemainingMiles(route: [TrailCoordinate], nearestIndex: Int) -> Double {
    let cumulative = cumulativeRouteMiles(route: route)
    guard
        !cumulative.isEmpty,
        nearestIndex >= 0,
        nearestIndex < cumulative.count
    else { return 0 }
    return max(0, cumulative.last! - cumulative[nearestIndex])
}

func nextWaypoint(distanceFromStartMiles: Double, waypoints: [TrailWaypoint]) -> TrailWaypoint? {
    waypoints
        .sorted(by: { $0.distanceFromStart < $1.distanceFromStart })
        .first(where: { $0.distanceFromStart > distanceFromStartMiles })
}

func etaHours(distanceRemainingMiles: Double, mph: Double = 2.0) -> Double {
    guard mph > 0 else { return 0 }
    return max(0, distanceRemainingMiles) / mph
}

func formatDuration(_ interval: TimeInterval) -> String {
    let totalSeconds = max(0, Int(interval))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

func celsiusToFahrenheit(_ c: Double) -> Int {
    Int((c * 9.0 / 5.0 + 32.0).rounded())
}

func kmhToMph(_ kmh: Double) -> Int {
    Int((kmh * 0.621371).rounded())
}

func wmoDescription(code: Int) -> String {
    if code == 0 { return "Clear Sky" }
    if (1...3).contains(code) { return "Partly Cloudy" }
    if code == 45 || code == 48 { return "Foggy" }
    if (51...67).contains(code) { return "Drizzle/Rain" }
    if (71...77).contains(code) { return "Snow" }
    if (80...82).contains(code) { return "Showers" }
    if (95...99).contains(code) { return "Thunderstorm" }
    return "Partly Cloudy"
}

let fallbackWeather: WeatherSnapshot = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
    formatter.dateFormat = "yyyy-MM-dd"

    let days = (0..<7).compactMap { offset -> WeatherDay? in
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else { return nil }
        let values = [(15.0, 8.0, "Sunny", 0), (13, 6, "Partly Cloudy", 20), (10, 3, "Rain", 80), (11, 4, "Showers", 60), (14, 7, "Cloudy", 30), (16, 9, "Partly Cloudy", 10), (17, 10, "Clear Sky", 0)]
        let value = values[min(offset, values.count - 1)]
        return WeatherDay(
            id: "fallback_\(offset)",
            date: formatter.string(from: date),
            highC: value.0,
            lowC: value.1,
            description: value.2,
            precipitationChance: value.3
        )
    }
    return WeatherSnapshot(
        temperatureC: 12,
        description: "Partly Cloudy",
        windKmh: 15,
        humidity: 65,
        sunrise: "06:30",
        sunset: "19:45",
        forecast: days,
        updatedAt: Date()
    )
}()

@MainActor
final class WeatherStore: ObservableObject {
    @Published var snapshot: WeatherSnapshot = fallbackWeather
    @Published var isLoading = false
    @Published var error: String?

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=45.3735&longitude=-121.6959&elevation=1829&current_weather=true&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode,sunrise,sunset&timezone=America%2FLos_Angeles&forecast_days=7") else {
            return
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            snapshot = decoded.toSnapshot()
            error = nil
        } catch {
            snapshot = fallbackWeather
            self.error = "Using cached weather data"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct CurrentWeather: Decodable {
        let temperature: Double?
        let windspeed: Double?
        let weathercode: Int?
    }

    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]
        let weathercode: [Int]
        let sunrise: [String]
        let sunset: [String]
    }

    let current_weather: CurrentWeather?
    let daily: Daily?

    func toSnapshot() -> WeatherSnapshot {
        let formatter = ISO8601DateFormatter()
        let days: [WeatherDay] = {
            guard let daily = daily else { return fallbackWeather.forecast }
            return daily.time.enumerated().map { index, date in
                WeatherDay(
                    id: "day_\(index)",
                    date: date,
                    highC: safe(daily.temperature_2m_max, index, fallback: fallbackWeather.forecast[min(index, fallbackWeather.forecast.count - 1)].highC),
                    lowC: safe(daily.temperature_2m_min, index, fallback: fallbackWeather.forecast[min(index, fallbackWeather.forecast.count - 1)].lowC),
                    description: wmoDescription(code: safe(daily.weathercode, index, fallback: 1)),
                    precipitationChance: safe(daily.precipitation_probability_max, index, fallback: 0)
                )
            }
        }()

        let sunrise = daily?.sunrise.first.flatMap { value -> String? in
            guard let date = formatter.date(from: value) else { return nil }
            return date.formatted(date: .omitted, time: .shortened)
        } ?? fallbackWeather.sunrise
        let sunset = daily?.sunset.first.flatMap { value -> String? in
            guard let date = formatter.date(from: value) else { return nil }
            return date.formatted(date: .omitted, time: .shortened)
        } ?? fallbackWeather.sunset

        return WeatherSnapshot(
            temperatureC: current_weather?.temperature ?? fallbackWeather.temperatureC,
            description: wmoDescription(code: current_weather?.weathercode ?? 1),
            windKmh: current_weather?.windspeed ?? fallbackWeather.windKmh,
            humidity: fallbackWeather.humidity,
            sunrise: sunrise,
            sunset: sunset,
            forecast: days,
            updatedAt: Date()
        )
    }

    private func safe<T>(_ array: [T], _ index: Int, fallback: T) -> T {
        if index >= 0 && index < array.count { return array[index] }
        return fallback
    }
}

@MainActor
final class SafetyStore: ObservableObject {
    @Published var contacts: [EmergencyContact]
    @Published var activeAlerts: [TrailWaypoint]

    private let defaults = UserDefaults.standard
    private let contactsKey = "phase2_emergency_contacts"

    init() {
        self.contacts = []
        self.activeAlerts = []
        loadContacts()
    }

    func updateLocation(_ location: CLLocation) {
        let coordinate = location.coordinate
        let candidates = timberlineTrailWaypoints.filter { waypoint in
            dangerousCrossingWaypointIDs.contains(waypoint.id)
        }

        var updates: [TrailWaypoint] = []
        for crossing in candidates {
            guard let coord = coordinateForWaypoint(crossing.id) else { continue }
            let meters = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            if meters <= 500 {
                updates.append(crossing)
            }
        }
        activeAlerts = updates
    }

    func addContact(name: String, phone: String, relationship: String, isPrimary: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty, !trimmedRelationship.isEmpty else { return }

        let contact = EmergencyContact(
            id: "contact_" + String(UUID().uuidString.prefix(8)),
            name: trimmedName,
            phone: trimmedPhone,
            relationship: trimmedRelationship,
            isPrimary: isPrimary
        )
        contacts.append(contact)
        persistContacts()
    }

    func removeContact(id: String) {
        contacts.removeAll { $0.id == id }
        persistContacts()
    }

    private func loadContacts() {
        if let decoded = PersistenceCodec.load([EmergencyContact].self, key: contactsKey, defaults: defaults), !decoded.isEmpty {
            contacts = decoded
        } else {
            contacts = [
                EmergencyContact(id: "contact_1", name: "John Doe", phone: "+1-555-0123", relationship: "Spouse", isPrimary: true),
                EmergencyContact(id: "contact_2", name: "Jane Smith", phone: "+1-555-0456", relationship: "Friend", isPrimary: false),
            ]
            persistContacts()
        }
    }

    private func persistContacts() {
        PersistenceCodec.persist(contacts, key: contactsKey, defaults: defaults)
    }

    private func coordinateForWaypoint(_ id: String) -> CLLocationCoordinate2D? {
        switch id {
        case "sandy-river-crossing":
            return CLLocationCoordinate2D(latitude: 45.3830, longitude: -121.7440)
        case "muddy-fork-crossing":
            return CLLocationCoordinate2D(latitude: 45.4022, longitude: -121.7890)
        case "eliot-branch-crossing":
            return CLLocationCoordinate2D(latitude: 45.4010, longitude: -121.6700)
        default:
            return nil
        }
    }
}

#if canImport(HealthKit)
@MainActor
final class HealthTrainingStore: ObservableObject {
    @Published private(set) var isAvailable: Bool
    @Published private(set) var isAuthorized = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSynced: Date?
    @Published private(set) var readiness: ReadinessBreakdown?
    @Published private(set) var weeklyMilesHistory: [Double] = [0, 0, 0, 0] // oldest -> newest
    @Published private(set) var averageWeeklyMiles: Double = 0
    @Published private(set) var longestHikeMiles: Double = 0
    @Published private(set) var monthlyElevationFeet: Double?
    @Published private(set) var activeWeeks: Int = 0

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var isObservingUpdates = false

    init() {
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
        guard isAvailable else { return }
        Task {
            await bootstrapAuthorizationState()
        }
    }

    func connectAndSync() async {
        guard isAvailable else {
            errorMessage = "Apple Health is only available on iPhone."
            return
        }
        guard !isLoading else { return }
        await performSync(requestAuthorizationIfNeeded: true)
    }

    func sync() async {
        guard isAvailable else { return }
        guard !isLoading else { return }
        await performSync(requestAuthorizationIfNeeded: false)
    }

    private func bootstrapAuthorizationState() async {
        do {
            let status = try await authorizationRequestStatus()
            if status == .unnecessary {
                isAuthorized = true
                startObservingHealthUpdates()
                await sync()
            }
        } catch {
            // Keep the connect CTA visible when status cannot be resolved.
        }
    }

    private func performSync(requestAuthorizationIfNeeded: Bool) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            if requestAuthorizationIfNeeded || !isAuthorized {
                try await requestAuthorization()
                isAuthorized = true
                startObservingHealthUpdates()
            }

            let workouts = try await loadRecentWorkouts(days: 28)
            let flights = try await loadRecentFlightsClimbed(days: 28)
            applyMetrics(workouts: workouts, flights: flights)
            lastSynced = Date()
            isAuthorized = true
        } catch {
            let detail = (error as NSError).localizedDescription
            if requestAuthorizationIfNeeded {
                errorMessage = "Unable to connect Apple Health (\(detail))."
            } else {
                errorMessage = "Failed to sync Apple Health data (\(detail))."
            }
        }
    }

    private func applyMetrics(workouts: [HKWorkout], flights: [HKQuantitySample]) {
        let now = Date()
        let msPerWeek: TimeInterval = 7 * 24 * 60 * 60
        var milesPerWeek: [Double] = [0, 0, 0, 0]

        for workout in workouts {
            let age = now.timeIntervalSince(workout.startDate)
            let weekIndex = 3 - min(3, max(0, Int(age / msPerWeek)))
            let miles = (workout.totalDistance?.doubleValue(for: .mile()) ?? 0)
            milesPerWeek[weekIndex] += miles
        }

        let longest = workouts.reduce(0.0) { max($0, $1.totalDistance?.doubleValue(for: .mile()) ?? 0) }
        let avgMiles = milesPerWeek.reduce(0, +) / 4.0
        let weeksWithActivity = milesPerWeek.filter { $0 > 0.01 }.count

        let flightsTotal = flights.reduce(0.0) { partial, sample in
            partial + sample.quantity.doubleValue(for: HKUnit.count())
        }
        let elevationFeet = flights.isEmpty ? nil : flightsTotal * 10.0

        weeklyMilesHistory = milesPerWeek
        averageWeeklyMiles = avgMiles
        longestHikeMiles = longest
        monthlyElevationFeet = elevationFeet
        activeWeeks = weeksWithActivity
        readiness = computeReadinessScore(
            weeklyMiles: avgMiles,
            longestHikeMiles: longest,
            elevationGainFeet: elevationFeet,
            activeWeeksInLastFour: weeksWithActivity
        )
    }

    private func requestAuthorization() async throws {
        let workoutType = HKObjectType.workoutType()
        guard let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) else {
            throw NSError(domain: "Health", code: 1)
        }

        let readTypes: Set<HKObjectType> = [workoutType, flightsType]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "Health", code: 2))
                }
            }
        }
    }

    private func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        let workoutType = HKObjectType.workoutType()
        guard let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) else {
            throw NSError(domain: "Health", code: 1)
        }

        let readTypes: Set<HKObjectType> = [workoutType, flightsType]
        return try await withCheckedThrowingContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func startObservingHealthUpdates() {
        guard !isObservingUpdates else { return }
        guard let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) else { return }

        let types: [HKSampleType] = [HKObjectType.workoutType(), flightsType]
        observerQueries.removeAll()

        for type in types {
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, _ in
                Task { @MainActor [weak self] in
                    defer { completionHandler() }
                    guard let self else { return }
                    await self.sync()
                }
            }
            observerQueries.append(query)
            store.execute(query)
        }

        isObservingUpdates = true
    }

    private func loadRecentWorkouts(days: Int) async throws -> [HKWorkout] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private func loadRecentFlightsClimbed(days: Int) async throws -> [HKQuantitySample] {
        guard let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) else {
            return []
        }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: flightsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let items = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: items)
            }
            store.execute(query)
        }
    }
}
#endif

// MARK: - Location + Map UI

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var latestLocation: CLLocation?
    @Published var isTracking = false
    @Published var sessions: [TrackingSession]

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let sessionsKey = "phase1_tracking_sessions"
    private var activeSession: TrackingSession?
    private var lastTrackedLocation: CLLocation?

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        self.sessions = []
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        loadSessions()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        if authorizationStatus == .notDetermined {
            requestPermission()
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }

        if activeSession == nil {
            activeSession = TrackingSession(
                id: UUID().uuidString,
                startedAt: Date(),
                endedAt: nil,
                points: []
            )
            lastTrackedLocation = nil
        }

        manager.startUpdatingLocation()
        isTracking = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
        lastTrackedLocation = nil

        guard var completed = activeSession else { return }
        completed.endedAt = Date()
        activeSession = nil
        sessions.insert(completed, at: 0)
        persistSessions()
    }

    func clearSessionLogs() {
        sessions = []
        activeSession = nil
        defaults.removeObject(forKey: sessionsKey)
    }

    var totalTrackedPoints: Int {
        sessions.reduce(0) { $0 + $1.points.count }
    }

    var totalTrackedDistanceMiles: Double {
        sessions.reduce(0) { $0 + distanceMiles(for: $1) }
    }

    func distanceMiles(for session: TrackingSession) -> Double {
        guard session.points.count > 1 else { return 0 }
        var totalMeters: CLLocationDistance = 0
        for index in 1..<session.points.count {
            let prev = session.points[index - 1]
            let next = session.points[index]
            let lhs = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let rhs = CLLocation(latitude: next.latitude, longitude: next.longitude)
            totalMeters += lhs.distance(from: rhs)
        }
        return totalMeters / 1609.344
    }

    func duration(for session: TrackingSession) -> TimeInterval {
        let end = session.endedAt ?? Date()
        return end.timeIntervalSince(session.startedAt)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startTracking()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        latestLocation = newest

        guard isTracking, newest.horizontalAccuracy >= 0 else { return }
        guard var session = activeSession else { return }

        if let last = lastTrackedLocation, newest.distance(from: last) < 5 {
            return
        }

        session.points.append(
            TrackPoint(
                id: UUID().uuidString,
                latitude: newest.coordinate.latitude,
                longitude: newest.coordinate.longitude,
                timestamp: newest.timestamp
            )
        )
        activeSession = session
        lastTrackedLocation = newest
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isTracking = false
        print("Location error: \(error.localizedDescription)")
    }

    private func loadSessions() {
        guard let data = defaults.data(forKey: sessionsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([TrackingSession].self, from: data) else { return }
        sessions = decoded
    }

    private func persistSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: sessionsKey)
    }
}

struct TrailMapView: UIViewRepresentable {
    let route: [TrailCoordinate]
    let userLocation: CLLocation?
    let mapType: MapType

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.delegate = context.coordinator
        configure(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        configure(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configure(_ mapView: MKMapView) {
        mapView.mapType = mkMapType(from: mapType)
        mapView.removeOverlays(mapView.overlays)

        let points = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let polyline = MKPolyline(coordinates: points, count: points.count)
        mapView.addOverlay(polyline)

        if let userLocation = userLocation {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            )
            mapView.setRegion(region, animated: true)
        } else if let first = points.first {
            let region = MKCoordinateRegion(
                center: first,
                latitudinalMeters: 16_000,
                longitudinalMeters: 16_000
            )
            mapView.setRegion(region, animated: false)
        }
    }

    private func mkMapType(from mapType: MapType) -> MKMapType {
        switch mapType {
        case .standard: return .standard
        case .satellite: return .satellite
        case .terrain: return .hybrid
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemGreen
            renderer.lineWidth = 4
            return renderer
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        AppFlowCoordinatorView(store: store)
        .preferredColorScheme(colorScheme(for: store.settings.appearance))
        .onChange(of: scenePhase) { phase in
            store.handleScenePhase(phase)
        }
    }

    private func colorScheme(for mode: AppearanceMode) -> ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Views

struct AuthView: View {
    @ObservedObject var store: AppStore
    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .signIn

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Timberline Trail")
                    .font(.largeTitle.bold())
                Text("Phase 1: local auth flow")
                    .foregroundColor(.secondary)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password (6+ chars)", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if let error = store.authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let info = store.authInfoMessage {
                    Text(info)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(mode == .signIn ? "Sign In" : "Create Account") {
                    Task {
                        if mode == .signIn {
                            await store.signIn(email: email, password: password)
                        } else {
                            await store.signUp(email: email, password: password)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(store.isAuthLoading)

                if mode == .signIn {
                    Button("Forgot password?") {
                        Task {
                            await store.requestPasswordReset(email: email)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(store.isAuthLoading)
                }

                Group {
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        Text("or")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.top, 8)

                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            store.handleAppleRequest(request)
                        },
                        onCompletion: { result in
                            Task {
                                await store.handleAppleCompletion(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .disabled(store.isAuthLoading)
                    
                    if store.isAuthLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Working...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationBarHidden(true)
            .onChange(of: mode) { _ in
                store.clearAuthMessages()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct OnboardingView: View {
    @ObservedObject var store: AppStore
    @State private var name = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome")
                    .font(.largeTitle.bold())
                Text("Set your hiker name to finish onboarding.")
                    .foregroundColor(.secondary)

                TextField("Your Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Get Started") {
                    store.completeOnboarding(name: name)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

struct MainTabView: View {
    @ObservedObject var store: AppStore
    @AppStorage("phase3_is_premium") private var isPremium = false

    var body: some View {
        TabView {
            MapHomeView(store: store)
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            if isPremium {
                NavigationDashboardView(store: store)
                    .tabItem {
                        Label("Navigate", systemImage: "location.north.line")
                    }
            } else {
                PremiumGateView(
                    featureName: "Navigation",
                    message: "Premium unlock is required for turn-by-turn route progress and waypoint guidance.",
                    isPremium: $isPremium
                )
                .tabItem {
                    Label("Navigate", systemImage: "location.north.line")
                }
            }

            if isPremium {
                TrainingReadinessView(store: store)
                    .tabItem {
                        Label("Train", systemImage: "heart.text.square")
                    }
            } else {
                PremiumGateView(
                    featureName: "Training",
                    message: "Premium unlock is required for readiness scoring and training guidance.",
                    isPremium: $isPremium
                )
                .tabItem {
                    Label("Train", systemImage: "heart.text.square")
                }
            }

            if isPremium {
                TripsView(store: store)
                    .tabItem {
                        Label("Trips", systemImage: "calendar")
                    }
            } else {
                PremiumGateView(
                    featureName: "Trips",
                    message: "Premium unlock is required for trip planning and party management.",
                    isPremium: $isPremium
                )
                .tabItem {
                    Label("Trips", systemImage: "calendar")
                }
            }

            TrailGuideView(store: store)
                .tabItem {
                    Label("Trail", systemImage: "mountain.2")
                }

            WeatherDashboardView(store: store)
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun")
                }

            SafetyHubView(store: store)
                .tabItem {
                    Label("Safety", systemImage: "shield")
                }

            SettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

private struct PremiumGateView: View {
    let featureName: String
    let message: String
    @Binding var isPremium: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(featureName) Is Premium")
                    .font(.title.bold())
                Text(message)
                    .foregroundColor(.secondary)
                Text("SKU: com.timberlinetrail.app.premium")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button("Unlock Premium (Demo)") {
                    isPremium = true
                }
                .buttonStyle(.borderedProminent)

                Button("Restore Purchases (Demo)") {
                    isPremium = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
}

private struct MapHomeView: View {
    @ObservedObject var store: AppStore
    @StateObject private var locationTracker = LocationTracker()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TrailMapView(
                    route: timberlineTrailCoordinates,
                    userLocation: locationTracker.latestLocation,
                    mapType: store.settings.mapType
                )
                .frame(height: 300)

                List {
                    Section("Trail") {
                        StatRow(label: "Route", value: "Timberline Trail")
                        StatRow(label: "Distance", value: "40.7 mi")
                        StatRow(label: "Elevation Gain", value: "9,000 ft")
                    }

                    Section("Location") {
                        StatRow(label: "Permission", value: locationStatusLabel(locationTracker.authorizationStatus))
                        if let location = locationTracker.latestLocation {
                            StatRow(label: "Lat", value: String(format: "%.4f", location.coordinate.latitude))
                            StatRow(label: "Lon", value: String(format: "%.4f", location.coordinate.longitude))
                        } else {
                            Text("No GPS fix yet.")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Button(locationTracker.isTracking ? "Stop Tracking" : "Start Tracking") {
                                if locationTracker.isTracking {
                                    locationTracker.stopTracking()
                                } else {
                                    locationTracker.startTracking()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            if locationTracker.authorizationStatus == .notDetermined {
                                Button("Allow Location") {
                                    locationTracker.requestPermission()
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        StatRow(label: "Saved Sessions", value: "\(locationTracker.sessions.count)")
                        StatRow(label: "Saved Points", value: "\(locationTracker.totalTrackedPoints)")
                        StatRow(label: "Tracked Distance", value: String(format: "%.2f mi", locationTracker.totalTrackedDistanceMiles))

                        if !locationTracker.sessions.isEmpty {
                            Button("Clear Session Logs", role: .destructive) {
                                locationTracker.clearSessionLogs()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if !locationTracker.sessions.isEmpty {
                        Section("Recent Tracks") {
                            ForEach(locationTracker.sessions.prefix(3)) { session in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.bold())
                                    Text(
                                        "\(session.points.count) pts • " +
                                        "\(String(format: "%.2f", locationTracker.distanceMiles(for: session))) mi • " +
                                        formatDuration(locationTracker.duration(for: session))
                                    )
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section("Active Trip") {
                        if let trip = store.activeTrip {
                            StatRow(label: "Trip", value: trip.name)
                            StatRow(label: "Dates", value: formatDateRange(start: trip.startDate, end: trip.endDate))
                            StatRow(label: "Days Until Start", value: "\(daysUntil(trip.startDate))")
                            StatRow(label: "Duration", value: "\(tripDurationDays(start: trip.startDate, end: trip.endDate)) days")
                        } else {
                            Text("No active trip yet.")
                                .foregroundColor(.secondary)
                        }
                    }
                    Section("Phase 1 Status") {
                        Text("Auth, onboarding, trips, settings, and base map/location are wired.")
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func locationStatusLabel(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Granted"
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        @unknown default:
            return "Unknown"
        }
    }
}

private struct NavigationDashboardView: View {
    @ObservedObject var store: AppStore
    @StateObject private var locationTracker = LocationTracker()
    @State private var lastRouteIndex: Int?

    var body: some View {
        NavigationView {
            List {
                Section("Navigation") {
                    if locationTracker.authorizationStatus == .notDetermined {
                        Button("Allow Location") {
                            locationTracker.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(locationTracker.isTracking ? "Stop Navigation Tracking" : "Start Navigation Tracking") {
                        if locationTracker.isTracking {
                            locationTracker.stopTracking()
                        } else {
                            locationTracker.startTracking()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Progress") {
                    let nearest = computedNearestIndex()
                    let remaining = distanceRemainingMiles(route: timberlineTrailCoordinates, nearestIndex: nearest)
                    let traveled = max(0, 40.7 - remaining)
                    StatRow(label: "Current Segment", value: segmentLabel(for: traveled))
                    StatRow(label: "Distance Remaining", value: String(format: "%.1f mi", remaining))
                    StatRow(label: "ETA @ 2.0 mph", value: String(format: "%.1f hrs", etaHours(distanceRemainingMiles: remaining)))
                    if let next = nextWaypoint(distanceFromStartMiles: traveled, waypoints: timberlineTrailWaypoints) {
                        StatRow(label: "Next Waypoint", value: "\(next.name) (\(String(format: "%.1f", next.distanceFromStart)) mi)")
                    } else {
                        StatRow(label: "Next Waypoint", value: "Loop complete")
                    }
                }

                Section("Conditions") {
                    StatRow(label: "Trail", value: "Open with caution at river crossings")
                    ForEach(timberlineTrailWaypoints.filter { dangerousCrossingWaypointIDs.contains($0.id) }) { crossing in
                        if let summary = crossing.summary {
                            Text("• \(crossing.name): \(summary)")
                                .font(.footnote)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Navigate")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func computedNearestIndex() -> Int {
        guard let location = locationTracker.latestLocation else { return 0 }
        let index = nearestRouteIndex(
            route: timberlineTrailCoordinates,
            userLocation: location.coordinate,
            lastIndex: lastRouteIndex,
            windowRadius: 25
        )
        lastRouteIndex = index
        return index
    }

    private func segmentLabel(for miles: Double) -> String {
        if miles < 3.5 { return "Timberline Lodge -> Paradise Park" }
        if miles < 16.8 { return "Paradise Park -> Cairn Basin" }
        if miles < 26.5 { return "Cairn Basin -> Cloud Cap" }
        return "Cloud Cap -> Timberline Lodge"
    }
}

private struct TrailGuideView: View {
    @ObservedObject var store: AppStore
    private let campsites = timberlineCampsites.sorted(by: { $0.distanceFromStart < $1.distanceFromStart })
    private let waterSources = timberlineWaterSources.sorted(by: { $0.distanceFromStart < $1.distanceFromStart })

    var body: some View {
        NavigationView {
            List {
                Section("Trail Overview") {
                    Text("Timberline Trail - Mount Hood, Oregon")
                        .font(.headline)
                    Text("40.7 miles • 9,000 ft elevation gain • Typical duration 3-5 days")
                    Text("Best season: July through September")
                }

                Section("Dangerous Crossings") {
                    ForEach(timberlineTrailWaypoints.filter { dangerousCrossingWaypointIDs.contains($0.id) }) { waypoint in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(waypoint.name)
                                .font(.subheadline.bold())
                            Text("Mile \(String(format: "%.1f", waypoint.distanceFromStart)) • High danger")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Water Sources") {
                    ForEach(waterSources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.subheadline.bold())
                            Text("Mile \(String(format: "%.1f", source.distanceFromStart)) • \(source.status.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let seasonal = source.seasonalNote {
                                Text(seasonal)
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section("Campsites") {
                    ForEach(campsites) { campsite in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(campsite.name)
                                .font(.subheadline.bold())
                            Text("Mile \(String(format: "%.1f", campsite.distanceFromStart)) • \(campsite.elevationFeet) ft • \(campsite.sites) sites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Permit: \(campsite.permitNotes)")
                                .font(.footnote)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Trail Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct WeatherDashboardView: View {
    @ObservedObject var store: AppStore
    @StateObject private var weatherStore = WeatherStore()

    var body: some View {
        NavigationView {
            List {
                Section("Current Conditions") {
                    StatRow(label: "Temperature", value: "\(celsiusToFahrenheit(weatherStore.snapshot.temperatureC))°F")
                    StatRow(label: "Summary", value: weatherStore.snapshot.description)
                    StatRow(label: "Wind", value: "\(kmhToMph(weatherStore.snapshot.windKmh)) mph")
                    StatRow(label: "Humidity", value: "\(weatherStore.snapshot.humidity)%")
                    StatRow(label: "Sunrise", value: weatherStore.snapshot.sunrise)
                    StatRow(label: "Sunset", value: weatherStore.snapshot.sunset)
                    if let error = weatherStore.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }

                Section("7-Day Forecast") {
                    ForEach(weatherStore.snapshot.forecast) { day in
                        HStack {
                            Text(day.date)
                            Spacer()
                            Text("\(celsiusToFahrenheit(day.highC))° / \(celsiusToFahrenheit(day.lowC))°")
                                .foregroundColor(.secondary)
                            Text("\(day.precipitationChance)%")
                                .foregroundColor(day.precipitationChance > 70 ? .red : (day.precipitationChance > 40 ? .orange : .green))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
                ToolbarItem(placement: .primaryAction) {
                    if weatherStore.isLoading {
                        ProgressView()
                    } else {
                        Button("Refresh") {
                            Task { await weatherStore.refresh() }
                        }
                    }
                }
            }
            .task {
                await weatherStore.refresh()
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct SafetyHubView: View {
    @ObservedObject var store: AppStore
    @StateObject private var safetyStore = SafetyStore()
    @StateObject private var locationTracker = LocationTracker()
    @State private var showingAdd = false
    @State private var draftName = ""
    @State private var draftPhone = ""
    @State private var draftRelationship = ""
    @State private var draftPrimary = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationView {
            List {
                Section("SOS") {
                    Button("SOS - Call 911", role: .destructive) {
                        triggerSOS()
                    }
                    .buttonStyle(.borderedProminent)
                    Text("Calls 911 and drafts SMS with your last known coordinates.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if !safetyStore.activeAlerts.isEmpty {
                    Section("Active Alerts") {
                        ForEach(safetyStore.activeAlerts) { alert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dangerous Crossing Ahead: \(alert.name)")
                                    .font(.subheadline.bold())
                                Text("Within 500m proximity. Assess crossing carefully.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                Section("Emergency Contacts") {
                    Button("Add Contact") {
                        showingAdd = true
                    }
                    ForEach(safetyStore.contacts) { contact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name + (contact.isPrimary ? " ★" : ""))
                                Text("\(contact.phone) • \(contact.relationship)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber || $0 == "+" })") {
                                    openURL(url)
                                }
                            } label: {
                                Image(systemName: "phone")
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                safetyStore.removeContact(id: contact.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Key Numbers") {
                    ForEach(store.safetyKeyNumbers) { number in
                        HStack {
                            Text(number.label)
                            Spacer()
                            Button(number.value) {
                                if let url = URL(string: "tel:\(number.value)") { openURL(url) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Safety")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
            .task {
                if locationTracker.authorizationStatus == .notDetermined {
                    locationTracker.requestPermission()
                }
                locationTracker.startTracking()
            }
            .onChange(of: locationTracker.latestLocation) { location in
                guard let unwrappedLocation = location else { return }
                safetyStore.updateLocation(unwrappedLocation)
            }
            .sheet(isPresented: $showingAdd) {
                NavigationView {
                    Form {
                        TextField("Name", text: $draftName)
                        TextField("Phone", text: $draftPhone)
                            .keyboardType(.phonePad)
                        TextField("Relationship", text: $draftRelationship)
                        Toggle("Primary Contact", isOn: $draftPrimary)
                    }
                    .navigationTitle("Add Contact")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                safetyStore.addContact(
                                    name: draftName,
                                    phone: draftPhone,
                                    relationship: draftRelationship,
                                    isPrimary: draftPrimary
                                )
                                draftName = ""
                                draftPhone = ""
                                draftRelationship = ""
                                draftPrimary = false
                                showingAdd = false
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func triggerSOS() {
        openURL(URL(string: "tel:911")!)
        let coordinate = locationTracker.latestLocation?.coordinate
        let lat = coordinate?.latitude ?? 0
        let lon = coordinate?.longitude ?? 0
        let body = "SOS I need help. My last known location was \(lat),\(lon)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        for contact in safetyStore.contacts {
            let sanitized = contact.phone.filter { $0.isNumber || $0 == "+" }
            if let smsURL = URL(string: "sms:\(sanitized)&body=\(body)") {
                openURL(smsURL)
            }
        }
    }
}

private struct TrainingReadinessView: View {
    @ObservedObject var store: AppStore
    #if canImport(HealthKit)
    @StateObject private var healthStore = HealthTrainingStore()
    #endif

    var body: some View {
        NavigationView {
            List {
                #if canImport(HealthKit)
                if !healthStore.isAvailable {
                    Section("Training") {
                        Text("Apple Health is only available on iPhone.")
                            .foregroundColor(.secondary)
                    }
                } else if !healthStore.isAuthorized {
                    Section("Connect Apple Health") {
                        Text("Connect Apple Health to compute readiness from your actual workouts.")
                            .foregroundColor(.secondary)
                        Button {
                            Task { await healthStore.connectAndSync() }
                        } label: {
                            if healthStore.isLoading {
                                ProgressView()
                            } else {
                                Text("Connect Apple Health")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(healthStore.isLoading)
                        if let error = healthStore.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    if let readiness = healthStore.readiness {
                        Section("Readiness") {
                            HStack {
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("\(readiness.score)%")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(readinessStatusColor(readinessStatus(for: readiness.score)))
                                    Text("ready for the trail")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            StatRow(label: "Weekly Miles", value: "\(String(format: "%.1f", healthStore.averageWeeklyMiles)) mi")
                            StatRow(label: "Longest Hike", value: "\(String(format: "%.1f", healthStore.longestHikeMiles)) mi")
                            StatRow(label: "Elevation Gain", value: healthStore.monthlyElevationFeet.map { "\(Int($0.rounded())) ft" } ?? "No data")
                            StatRow(label: "Consistency", value: "\(healthStore.activeWeeks)/4 wks")
                        }

                        Section("Past 4 Weeks") {
                            ForEach(Array(healthStore.weeklyMilesHistory.enumerated()), id: \.offset) { index, miles in
                                HStack {
                                    Text(weekLabel(index))
                                        .foregroundColor(.secondary)
                                    ProgressView(value: min(1.0, miles / 15.0))
                                        .tint(.green)
                                    Text(String(format: "%.1f mi", miles))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    Section("Training Guidance") {
                        Text("Target weekly miles: 15 mi/week")
                        Text("Target long hike: 8 miles")
                        Text("Target elevation: 1,000 ft/month")
                        Text("Consistency target: 4 of 4 active weeks")
                    }

                    Section("Current Week") {
                        Text("Week \(currentTrainingWeek()) of 20")
                        Text("Recommended: one long hike + one moderate midweek hike + recovery walks")
                    }

                    Section("Sync") {
                        if let lastSynced = healthStore.lastSynced {
                            Text("Apple Health synced \(relativeSyncText(lastSynced))")
                                .foregroundColor(.secondary)
                        }
                        Button {
                            Task { await healthStore.sync() }
                        } label: {
                            if healthStore.isLoading {
                                ProgressView()
                            } else {
                                Text("Refresh")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(healthStore.isLoading)
                        if let error = healthStore.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
                #else
                Section("Training") {
                    Text("HealthKit not available in this build.")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func currentTrainingWeek() -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)) ?? Date()
        let weeks = calendar.dateComponents([.weekOfYear], from: start, to: Date()).weekOfYear ?? 0
        return min(20, max(1, weeks + 1))
    }

    private func weekLabel(_ index: Int) -> String {
        switch index {
        case 0: return "3 weeks ago"
        case 1: return "2 weeks ago"
        case 2: return "Last week"
        default: return "This week"
        }
    }

    private func relativeSyncText(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\((hours / 24))d ago"
    }

    private func readinessStatusColor(_ status: ReadinessStatus) -> Color {
        switch status {
        case .great: return .green
        case .ok: return .orange
        case .low: return .red
        }
    }
}

private struct TripsView: View {
    @ObservedObject var store: AppStore
    @State private var isCreatingTrip = false
    @State private var editingTrip: Trip?
    @State private var selectedTrip: Trip?

    var body: some View {
        NavigationView {
            List {
                if store.trips.isEmpty {
                    Text("No trips yet. Create your first trip.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.trips) { trip in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                selectedTrip = trip
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(trip.name)
                                                .font(.headline)
                                            if trip.id == store.activeTripID {
                                                Text("ACTIVE")
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.green.opacity(0.2))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text(formatDateRange(start: trip.startDate, end: trip.endDate))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    HStack {
                                        Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.deleteTrip(id: trip.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingTrip = trip
                            } label: {
                                Label("Edit", systemImage: "calendar")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if trip.id != store.activeTripID {
                                Button {
                                    store.setActiveTrip(id: trip.id)
                                } label: {
                                    Label("Set Active", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreatingTrip) {
                CreateTripView(store: store)
            }
            .sheet(item: $editingTrip) { trip in
                EditTripView(store: store, trip: trip)
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(store: store, tripID: trip.id)
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct TripDetailView: View {
    @ObservedObject var store: AppStore
    let tripID: String
    @Environment(\.dismiss) private var dismiss
    @State private var packItems: [PackItem] = []
    @State private var tripDaysForPack = 4
    @State private var showPackEditor = false
    @State private var editingPackItemID: String?
    @State private var draftPackName = ""
    @State private var draftPackWeight = ""
    @State private var draftPackConsumable = false

    private var trip: Trip? {
        store.trips.first(where: { $0.id == tripID })
    }

    var body: some View {
        NavigationView {
            List {
                if let trip = trip {
                    Section("Overview") {
                        StatRow(label: "Trip", value: trip.name)
                        StatRow(label: "Dates", value: formatDateRange(start: trip.startDate, end: trip.endDate))
                        StatRow(label: "Days Until Start", value: "\(daysUntil(trip.startDate))")
                        StatRow(label: "Duration", value: "\(tripDurationDays(start: trip.startDate, end: trip.endDate)) days")
                        StatRow(label: "Party Size", value: "\(trip.partyCount)")
                    }

                    Section("Hiking Party") {
                        Text("You (Organizer)")
                        if trip.partyCount > 1 {
                            ForEach(1..<trip.partyCount, id: \.self) { index in
                                Text("Party Member \(index)")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No additional party members yet.")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Pack Summary") {
                        let base = calculateBaseWeightOz(items: packItems)
                        let total = calculateTotalPackWeightOz(baseWeightOz: base, tripDays: tripDaysForPack)
                        StatRow(label: "Trip Days", value: "\(tripDaysForPack)")
                        StatRow(label: "Base Weight", value: String(format: "%.1f lb", base / 16))
                        StatRow(label: "Food + Water", value: String(format: "%.1f lb", estimateFoodAndWaterWeightOz(tripDays: tripDaysForPack) / 16))
                        StatRow(label: "Total Weight", value: String(format: "%.1f lb", total / 16))
                        StatRow(label: "Class", value: packClass(forBaseWeightOz: base).rawValue.capitalized)
                        Stepper("Trip Days: \(tripDaysForPack)", value: $tripDaysForPack, in: 1...14)
                            .onChange(of: tripDaysForPack) { _ in persistPackItems() }
                    }

                    Section("Pack List") {
                        Button("Add Pack Item") {
                            startAddingPackItem()
                        }
                        .buttonStyle(.borderedProminent)

                        ForEach(packItems.indices, id: \.self) { index in
                            HStack(spacing: 10) {
                                Button {
                                    packItems[index].isIncluded.toggle()
                                    persistPackItems()
                                } label: {
                                    Image(systemName: packItems[index].isIncluded ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(packItems[index].isIncluded ? .green : .secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(packItems[index].name)
                                    Text(String(format: "%.1f oz%@", packItems[index].weightOz, packItems[index].consumable ? " • consumable" : ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditingPackItem(packItems[index])
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    removePackItem(id: packItems[index].id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    startEditingPackItem(packItems[index])
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }

                    Section("Checklist") {
                        Text("• Confirm permit requirements")
                        Text("• Verify river crossing conditions")
                        Text("• Finalize emergency contacts")
                        Text("• Complete food + water carry plan")
                        Text("• Charge navigation devices")
                    }

                    Section("Trail Highlights") {
                        ForEach(timberlineTrailWaypoints.prefix(6)) { waypoint in
                            Text("• Mile \(String(format: "%.1f", waypoint.distanceFromStart)) - \(waypoint.name)")
                        }
                    }
                } else {
                    Text("Trip not found.")
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadPackItems()
            }
            .sheet(isPresented: $showPackEditor) {
                NavigationView {
                    Form {
                        Section("Item") {
                            TextField("Name", text: $draftPackName)
                            TextField("Weight (oz)", text: $draftPackWeight)
                                .keyboardType(.decimalPad)
                            Toggle("Consumable", isOn: $draftPackConsumable)
                        }
                    }
                    .navigationTitle(editingPackItemID == nil ? "Add Pack Item" : "Edit Pack Item")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPackEditor = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                savePackEditor()
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func packStorageKey() -> String {
        "phase3_trip_pack_items_\(tripID)"
    }

    private func packDaysKey() -> String {
        "phase3_trip_pack_days_\(tripID)"
    }

    private func loadPackItems() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: packStorageKey()),
           let decoded = try? JSONDecoder().decode([PackItem].self, from: data) {
            packItems = decoded
        } else {
            packItems = defaultTripPackItems
        }

        let days = defaults.integer(forKey: packDaysKey())
        tripDaysForPack = days == 0 ? max(1, tripDurationDays(start: trip?.startDate ?? "", end: trip?.endDate ?? "")) : days
    }

    private func persistPackItems() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(packItems) {
            defaults.set(data, forKey: packStorageKey())
        }
        defaults.set(tripDaysForPack, forKey: packDaysKey())
    }

    private func startAddingPackItem() {
        editingPackItemID = nil
        draftPackName = ""
        draftPackWeight = ""
        draftPackConsumable = false
        showPackEditor = true
    }

    private func startEditingPackItem(_ item: PackItem) {
        editingPackItemID = item.id
        draftPackName = item.name
        draftPackWeight = String(format: "%.1f", item.weightOz)
        draftPackConsumable = item.consumable
        showPackEditor = true
    }

    private func savePackEditor() {
        let trimmedName = draftPackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let weight = Double(draftPackWeight), weight > 0 else { return }

        if let editingID = editingPackItemID,
           let index = packItems.firstIndex(where: { $0.id == editingID }) {
            packItems[index].name = trimmedName
            packItems[index].weightOz = weight
            packItems[index].consumable = draftPackConsumable
        } else {
            let newItem = PackItem(
                id: "custom_" + String(UUID().uuidString.prefix(8)),
                name: trimmedName,
                weightOz: weight,
                consumable: draftPackConsumable,
                isIncluded: true
            )
            packItems.append(newItem)
        }

        persistPackItems()
        showPackEditor = false
    }

    private func removePackItem(id: String) {
        packItems.removeAll { $0.id == id }
        persistPackItems()
    }
}

private struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationView {
            Form {
                Section("Trip Details") {
                    TextField("Trip name", text: $name)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createTrip(name: name, startDate: startDate, endDate: endDate)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let trip: Trip

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date

    init(store: AppStore, trip: Trip) {
        self.store = store
        self.trip = trip

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let parsedStart = formatter.date(from: trip.startDate) ?? Date()
        let parsedEnd = formatter.date(from: trip.endDate) ?? parsedStart
        _name = State(initialValue: trip.name)
        _startDate = State(initialValue: parsedStart)
        _endDate = State(initialValue: max(parsedStart, parsedEnd))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Trip Details") {
                    TextField("Trip name", text: $name)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateTrip(id: trip.id, name: name, startDate: startDate, endDate: endDate)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationView {
            Form {
                Section("Profile") {
                    NavigationLink {
                        ProfileView(store: store)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(initials(from: store.profile?.name ?? "H"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.green)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.profile?.name ?? "Hiker")
                                Text(store.session?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { store.settings.appearance },
                        set: { newValue in
                            var copy = store.settings
                            copy.appearance = newValue
                            store.updateSettings(copy)
                        }
                    )) {
                        Text("System").tag(AppearanceMode.system)
                        Text("Light").tag(AppearanceMode.light)
                        Text("Dark").tag(AppearanceMode.dark)
                    }
                }

                Section("Units") {
                    Picker("System", selection: Binding(
                        get: { store.settings.units },
                        set: { newValue in
                            var copy = store.settings
                            copy.units = newValue
                            store.updateSettings(copy)
                        }
                    )) {
                        Text("Imperial").tag(Units.imperial)
                        Text("Metric").tag(Units.metric)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Map") {
                    Picker("Map Type", selection: Binding(
                        get: { store.settings.mapType },
                        set: { newValue in
                            var copy = store.settings
                            copy.mapType = newValue
                            store.updateSettings(copy)
                        }
                    )) {
                        ForEach(MapType.allCases) { mapType in
                            Text(mapType.rawValue.capitalized).tag(mapType)
                        }
                    }
                }

                Section("GPS Update Interval") {
                    Picker("Interval", selection: Binding(
                        get: { store.settings.gpsInterval },
                        set: { newValue in
                            var copy = store.settings
                            copy.gpsInterval = newValue
                            store.updateSettings(copy)
                        }
                    )) {
                        ForEach(GPSInterval.allCases) { interval in
                            Text("\(interval.rawValue) sec").tag(interval)
                        }
                    }
                }

                Section("Auto-Lock") {
                    Toggle("Auto Sign-Out", isOn: Binding(
                        get: { store.settings.autoLockEnabled },
                        set: { newValue in
                            var copy = store.settings
                            copy.autoLockEnabled = newValue
                            store.updateSettings(copy)
                        }
                    ))

                    if store.settings.autoLockEnabled {
                        Picker("Timeout", selection: Binding(
                            get: { store.settings.autoLockMinutes },
                            set: { newValue in
                                var copy = store.settings
                                copy.autoLockMinutes = newValue
                                store.updateSettings(copy)
                            }
                        )) {
                            ForEach(AutoLockMinutes.allCases) { option in
                                Text("\(option.rawValue) min").tag(option)
                            }
                        }
                    }
                }

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        store.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileAvatarButton(store: store)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let value = parts.map { String($0.prefix(1)).uppercased() }.joined()
        return value.isEmpty ? "H" : value
    }
}

private struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State private var draftName = ""
    @State private var draftPhotoURI: String?
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false

    var body: some View {
        Form {
            Section("Profile") {
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        ProfileAvatarCircle(name: draftName.isEmpty ? (store.profile?.name ?? "Hiker") : draftName, photoURI: draftPhotoURI, imageOverride: selectedImage, size: 86)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.vertical, 4)

                Button("Change Photo") {
                    showingImagePicker = true
                }

                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)
                if let email = store.session?.email {
                    HStack {
                        Text("Email")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(email)
                    }
                }
            }

            Section {
                Button("Save Profile") {
                    let finalPhotoURI = persistSelectedImageIfNeeded() ?? draftPhotoURI
                    store.updateProfile(name: draftName, photoURI: finalPhotoURI)
                    dismiss()
                }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            draftName = store.profile?.name ?? ""
            draftPhotoURI = store.profile?.photoURI
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    private func persistSelectedImageIfNeeded() -> String? {
#if canImport(UIKit)
        guard let selectedImage = selectedImage else { return nil }
        guard let data = selectedImage.jpegData(compressionQuality: 0.85) else { return nil }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let directory = directory else { return nil }
        let url = directory.appendingPathComponent("profile-photo.jpg")
        do {
            try data.write(to: url, options: Data.WritingOptions.atomic)
            return url.path
        } catch {
            return nil
        }
#else
        return nil
#endif
    }
}

private struct ProfileAvatarButton: View {
    @ObservedObject var store: AppStore
    @State private var showingProfile = false

    var body: some View {
        Button {
            showingProfile = true
        } label: {
            ProfileAvatarCircle(name: store.profile?.name ?? "Hiker", photoURI: store.profile?.photoURI, imageOverride: nil, size: 28)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView(store: store)
            }
            .navigationViewStyle(.stack)
        }
    }
}

private struct ProfileAvatarCircle: View {
    let name: String
    let photoURI: String?
    let imageOverride: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
#if canImport(UIKit)
            if let imageOverride = imageOverride {
                Image(uiImage: imageOverride)
                    .resizable()
                    .scaledToFill()
            } else if let photoURI = photoURI,
                      let image = UIImage(contentsOfFile: photoURI) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackAvatar
            }
#else
            fallbackAvatar
#endif
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.green.opacity(0.2))
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: max(12, size * 0.38), weight: .semibold))
                    .foregroundColor(.green)
            )
    }

    private func initials(from value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        let candidate = parts.map { String($0.prefix(1)).uppercased() }.joined()
        return candidate.isEmpty ? "H" : candidate
    }
}

#if canImport(UIKit)
private struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }
    }
}
#endif
private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
