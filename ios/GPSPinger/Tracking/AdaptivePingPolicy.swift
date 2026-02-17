import CoreLocation
import Foundation

enum PingMode: String {
    case moving
    case stationaryDay
    case homeOrNight
}

struct AdaptivePingContext {
    let timestamp: Date
    let location: CLLocation
    let isAtHome: Bool
    let isNight: Bool
    let lastSentAt: Date?
    let lastSentLocation: CLLocation?
    let settings: TrackerSettings
}

struct PingDecision {
    let shouldSend: Bool
    let mode: PingMode
    let minIntervalSeconds: TimeInterval
    let elapsedSinceLastPingSeconds: TimeInterval
    let minDistanceMeters: CLLocationDistance
    let distanceSinceLastPingMeters: CLLocationDistance
    let recommendedAccuracy: CLLocationAccuracy
    let recommendedDistanceFilter: CLLocationDistance
}

struct AdaptivePingPolicy {
    private let movingSpeedMpsThreshold = 1.5

    func decide(_ context: AdaptivePingContext) -> PingDecision {
        let moving = isMoving(context)
        let mode: PingMode

        if moving {
            mode = .moving
        } else if context.isAtHome || context.isNight {
            mode = .homeOrNight
        } else {
            mode = .stationaryDay
        }

        let minInterval = interval(for: mode, settings: context.settings)
        let minDistance = distance(for: mode, settings: context.settings)
        let elapsed = context.lastSentAt.map { context.timestamp.timeIntervalSince($0) } ?? .infinity
        let distance = context.lastSentLocation.map { context.location.distance(from: $0) } ?? .infinity
        let shouldSend = elapsed >= minInterval && distance >= minDistance

        return PingDecision(
            shouldSend: shouldSend,
            mode: mode,
            minIntervalSeconds: minInterval,
            elapsedSinceLastPingSeconds: elapsed,
            minDistanceMeters: minDistance,
            distanceSinceLastPingMeters: distance,
            recommendedAccuracy: accuracy(for: mode),
            recommendedDistanceFilter: filter(for: mode)
        )
    }

    private func isMoving(_ context: AdaptivePingContext) -> Bool {
        if context.location.speed >= movingSpeedMpsThreshold {
            return true
        }

        guard
            let lastLocation = context.lastSentLocation,
            let lastSentAt = context.lastSentAt
        else {
            return false
        }

        let elapsed = max(context.timestamp.timeIntervalSince(lastSentAt), 1)
        let estimatedSpeed = context.location.distance(from: lastLocation) / elapsed
        return estimatedSpeed >= movingSpeedMpsThreshold
    }

    private func interval(for mode: PingMode, settings: TrackerSettings) -> TimeInterval {
        switch mode {
        case .moving:
            return max(5, settings.movingIntervalSeconds)
        case .stationaryDay:
            return max(60, TimeInterval(settings.stationaryDayIntervalMinutes * 60))
        case .homeOrNight:
            return max(120, TimeInterval(settings.homeOrNightIntervalMinutes * 60))
        }
    }

    private func distance(for mode: PingMode, settings: TrackerSettings) -> CLLocationDistance {
        switch mode {
        case .moving:
            return max(10, settings.minDistanceMeters)
        case .stationaryDay:
            return max(20, settings.minDistanceMeters * 2)
        case .homeOrNight:
            return max(40, settings.minDistanceMeters * 4)
        }
    }

    private func accuracy(for mode: PingMode) -> CLLocationAccuracy {
        switch mode {
        case .moving:
            return kCLLocationAccuracyNearestTenMeters
        case .stationaryDay:
            return kCLLocationAccuracyHundredMeters
        case .homeOrNight:
            return kCLLocationAccuracyKilometer
        }
    }

    private func filter(for mode: PingMode) -> CLLocationDistance {
        switch mode {
        case .moving:
            return 20
        case .stationaryDay:
            return 80
        case .homeOrNight:
            return 250
        }
    }
}
