import Foundation

struct TrackerSettings: Codable, Equatable {
    var endpointURLString: String
    var bearerToken: String
    var homeLatitude: Double
    var homeLongitude: Double
    var movingIntervalSeconds: TimeInterval
    var stationaryDayIntervalMinutes: Int
    var homeOrNightIntervalMinutes: Int
    var minDistanceMeters: Double
    var dayStartsMinutesFromMidnight: Int
    var dayEndsMinutesFromMidnight: Int

    var endpointURL: URL? {
        URL(string: endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static let defaults = TrackerSettings(
        endpointURLString: "http://localhost:8787/ping",
        bearerToken: "",
        homeLatitude: 37.332,
        homeLongitude: -122.031,
        movingIntervalSeconds: 30,
        stationaryDayIntervalMinutes: 15,
        homeOrNightIntervalMinutes: 30,
        minDistanceMeters: 30,
        dayStartsMinutesFromMidnight: 6 * 60,
        dayEndsMinutesFromMidnight: 22 * 60
    )
}

extension TrackerSettings {
    private enum CodingKeys: String, CodingKey {
        case endpointURLString
        case bearerToken
        case homeLatitude
        case homeLongitude
        case movingIntervalSeconds
        case stationaryDayIntervalMinutes
        case homeOrNightIntervalMinutes
        case minDistanceMeters
        case dayStartsMinutesFromMidnight
        case dayEndsMinutesFromMidnight

        // legacy keys kept for migration
        case stationaryDayIntervalSeconds
        case homeOrNightIntervalSeconds
        case nightStartsHour
        case nightEndsHour
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        endpointURLString = try values.decodeIfPresent(String.self, forKey: .endpointURLString) ?? Self.defaults.endpointURLString
        bearerToken = try values.decodeIfPresent(String.self, forKey: .bearerToken) ?? Self.defaults.bearerToken
        homeLatitude = try values.decodeIfPresent(Double.self, forKey: .homeLatitude) ?? Self.defaults.homeLatitude
        homeLongitude = try values.decodeIfPresent(Double.self, forKey: .homeLongitude) ?? Self.defaults.homeLongitude
        movingIntervalSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .movingIntervalSeconds) ?? Self.defaults.movingIntervalSeconds
        minDistanceMeters = try values.decodeIfPresent(Double.self, forKey: .minDistanceMeters) ?? Self.defaults.minDistanceMeters

        if let dayMinutes = try values.decodeIfPresent(Int.self, forKey: .stationaryDayIntervalMinutes) {
            stationaryDayIntervalMinutes = max(1, dayMinutes)
        } else if let legacySeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .stationaryDayIntervalSeconds) {
            stationaryDayIntervalMinutes = max(1, Int((legacySeconds / 60).rounded()))
        } else {
            stationaryDayIntervalMinutes = Self.defaults.stationaryDayIntervalMinutes
        }

        if let nightMinutes = try values.decodeIfPresent(Int.self, forKey: .homeOrNightIntervalMinutes) {
            homeOrNightIntervalMinutes = max(1, nightMinutes)
        } else if let legacySeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .homeOrNightIntervalSeconds) {
            homeOrNightIntervalMinutes = max(1, Int((legacySeconds / 60).rounded()))
        } else {
            homeOrNightIntervalMinutes = Self.defaults.homeOrNightIntervalMinutes
        }

        if let startMinutes = try values.decodeIfPresent(Int.self, forKey: .dayStartsMinutesFromMidnight),
           let endMinutes = try values.decodeIfPresent(Int.self, forKey: .dayEndsMinutesFromMidnight) {
            dayStartsMinutesFromMidnight = Self.clampDayMinute(startMinutes)
            dayEndsMinutesFromMidnight = Self.clampDayMinute(endMinutes)
        } else {
            // legacy migration: night window -> day window
            let legacyNightStart = try values.decodeIfPresent(Int.self, forKey: .nightStartsHour) ?? 22
            let legacyNightEnd = try values.decodeIfPresent(Int.self, forKey: .nightEndsHour) ?? 6
            dayStartsMinutesFromMidnight = Self.clampDayMinute(legacyNightEnd * 60)
            dayEndsMinutesFromMidnight = Self.clampDayMinute(legacyNightStart * 60)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(endpointURLString, forKey: .endpointURLString)
        try container.encode(bearerToken, forKey: .bearerToken)
        try container.encode(homeLatitude, forKey: .homeLatitude)
        try container.encode(homeLongitude, forKey: .homeLongitude)
        try container.encode(movingIntervalSeconds, forKey: .movingIntervalSeconds)
        try container.encode(stationaryDayIntervalMinutes, forKey: .stationaryDayIntervalMinutes)
        try container.encode(homeOrNightIntervalMinutes, forKey: .homeOrNightIntervalMinutes)
        try container.encode(minDistanceMeters, forKey: .minDistanceMeters)
        try container.encode(dayStartsMinutesFromMidnight, forKey: .dayStartsMinutesFromMidnight)
        try container.encode(dayEndsMinutesFromMidnight, forKey: .dayEndsMinutesFromMidnight)
    }

    private static func clampDayMinute(_ value: Int) -> Int {
        min(max(0, value), (24 * 60) - 1)
    }
}
