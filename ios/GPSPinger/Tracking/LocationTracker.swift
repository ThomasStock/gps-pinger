import Combine
import CoreLocation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LocationTracker: NSObject, ObservableObject {
    @Published private(set) var isTracking = false
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastPingAt: Date?
    @Published private(set) var lastError: String?

    private let manager: CLLocationManager
    private let settingsStore: SettingsStore
    private let logStore: AppLogStore
    private let defaults: UserDefaults
    private let policy = AdaptivePingPolicy()
    private let uploader = LocationUploader()
    private let homeRegionIdentifier = "gps_pinger.home"
    private let homeRadiusMeters: CLLocationDistance = 100
    private let trackingStateKey = "gps_pinger.isTracking.v1"
    private let deviceId: String
    private let supportsBackgroundLocationUpdates: Bool

    private var authorizationStatus: CLAuthorizationStatus
    private var lastMode: PingMode = .stationaryDay
    private var lastSentAt: Date?
    private var lastSentLocation: CLLocation?
    private var continuousUpdatesEnabled = false
    private var uploadInFlight = false
    private var pendingSetHomeFromNextLocation = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore,
        logStore: AppLogStore,
        manager: CLLocationManager = CLLocationManager(),
        defaults: UserDefaults = .standard
    ) {
        self.settingsStore = settingsStore
        self.logStore = logStore
        self.manager = manager
        self.defaults = defaults
        authorizationStatus = manager.authorizationStatus

        #if canImport(UIKit)
        deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        deviceId = UUID().uuidString
        #endif

        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            supportsBackgroundLocationUpdates = modes.contains("location")
        } else {
            supportsBackgroundLocationUpdates = false
        }

        super.init()

        manager.delegate = self
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 80

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                self.updateHomeRegion()
                self.logStore.add("Settings updated.")
            }
            .store(in: &cancellables)

        isTracking = defaults.bool(forKey: trackingStateKey)
        if isTracking {
            logStore.add("Restored tracking state from previous session.")
            manager.requestAlwaysAuthorization()
            evaluateAuthorizationAndStartIfAllowed()
        }
    }

    func startTracking() {
        guard !isTracking else {
            return
        }

        isTracking = true
        persistTrackingState()
        logStore.add("Start requested.")
        manager.requestAlwaysAuthorization()
        evaluateAuthorizationAndStartIfAllowed()
    }

    func stopTracking() {
        guard isTracking else {
            return
        }

        isTracking = false
        persistTrackingState()
        continuousUpdatesEnabled = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()

        for region in manager.monitoredRegions where region.identifier == homeRegionIdentifier {
            manager.stopMonitoring(for: region)
        }

        logStore.add("Tracking stopped.")
    }

    func setHomeToCurrentLocation() {
        if let location = lastLocation {
            applyHome(location, source: "cached")
            return
        }

        pendingSetHomeFromNextLocation = true
        lastError = nil
        logStore.add("Set Home requested. Fetching current location.")

        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        manager.requestLocation()
    }

    func setHome(to coordinate: CLLocationCoordinate2D, source: String = "map center") {
        pendingSetHomeFromNextLocation = false
        lastError = nil
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        applyHome(location, source: source)
    }

    private func evaluateAuthorizationAndStartIfAllowed() {
        guard isTracking else {
            return
        }

        switch authorizationStatus {
        case .authorizedAlways:
            if supportsBackgroundLocationUpdates {
                lastError = nil
            } else {
                lastError = "Background location mode is missing from Info.plist."
            }
            startServices()
        case .authorizedWhenInUse:
            lastError = "Enable \"Always\" location for background pings."
            logStore.add("Authorization is only 'When In Use'.")
        case .denied, .restricted:
            lastError = "Location permission denied."
            logStore.add("Location permission denied or restricted.")
        case .notDetermined:
            logStore.add("Waiting for location permission.")
        @unknown default:
            logStore.add("Unknown location authorization status.")
        }
    }

    private func startServices() {
        #if targetEnvironment(simulator)
        manager.allowsBackgroundLocationUpdates = false
        logStore.add("Running on simulator: background-location flag left disabled.")
        #else
        manager.allowsBackgroundLocationUpdates = supportsBackgroundLocationUpdates
        #endif

        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
        updateHomeRegion()

        if !continuousUpdatesEnabled {
            manager.startUpdatingLocation()
            continuousUpdatesEnabled = true
        }

        logStore.add("Location services started.")
    }

    private func processLocation(_ location: CLLocation, at timestamp: Date = Date()) {
        lastLocation = location

        if pendingSetHomeFromNextLocation {
            pendingSetHomeFromNextLocation = false
            applyHome(location, source: "fresh")
        }

        guard isTracking else {
            return
        }

        let settings = settingsStore.settings
        let context = AdaptivePingContext(
            timestamp: timestamp,
            location: location,
            isAtHome: isAtHome(location: location, settings: settings),
            isNight: !isDay(time: timestamp, settings: settings),
            lastSentAt: lastSentAt,
            lastSentLocation: lastSentLocation,
            settings: settings
        )

        let decision = policy.decide(context)
        if decision.mode != lastMode {
            logStore.add("Mode changed: \(lastMode.rawValue) -> \(decision.mode.rawValue).")
            lastMode = decision.mode
        }

        applyRadioTuning(decision)

        logStore.add(
            """
            Ping attempt mode=\(decision.mode.rawValue), send=\(decision.shouldSend), \
            elapsed=\(formatSeconds(decision.elapsedSinceLastPingSeconds))/\(Int(decision.minIntervalSeconds))s, \
            distance=\(formatMeters(decision.distanceSinceLastPingMeters))/\(Int(decision.minDistanceMeters))m.
            """
        )

        guard decision.shouldSend else {
            return
        }

        guard !uploadInFlight else {
            logStore.add("Ping skipped: upload already in flight.")
            return
        }

        uploadInFlight = true
        Task {
            await upload(location: location, mode: decision.mode, settings: settings)
        }
    }

    private func upload(location: CLLocation, mode: PingMode, settings: TrackerSettings) async {
        defer {
            uploadInFlight = false
        }

        do {
            try await uploader.upload(
                location: location,
                mode: mode,
                settings: settings,
                deviceId: deviceId
            )
            lastPingAt = Date()
            lastSentAt = lastPingAt
            lastSentLocation = location
            lastError = nil
            logStore.add("Ping sent successfully in mode \(mode.rawValue).")
        } catch UploadError.invalidEndpoint {
            lastError = "Invalid endpoint URL."
            logStore.add("Ping failed: invalid endpoint URL.")
        } catch UploadError.httpStatus(let status) {
            lastError = "Server rejected ping (HTTP \(status))."
            logStore.add("Ping failed with HTTP \(status).")
        } catch {
            lastError = "Upload failed: \(error.localizedDescription)"
            logStore.add("Ping failed: \(error.localizedDescription)")
        }
    }

    private func applyRadioTuning(_ decision: PingDecision) {
        manager.desiredAccuracy = decision.recommendedAccuracy
        manager.distanceFilter = decision.recommendedDistanceFilter

        let shouldUseContinuousUpdates = decision.mode != .homeOrNight

        if shouldUseContinuousUpdates && !continuousUpdatesEnabled {
            manager.startUpdatingLocation()
            continuousUpdatesEnabled = true
        } else if !shouldUseContinuousUpdates && continuousUpdatesEnabled {
            manager.stopUpdatingLocation()
            continuousUpdatesEnabled = false
        }
    }

    private func isDay(time: Date, settings: TrackerSettings) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minuteOfDay = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        let start = settings.dayStartsMinutesFromMidnight
        let end = settings.dayEndsMinutesFromMidnight

        if start == end {
            return true
        }

        if start < end {
            return (start ..< end).contains(minuteOfDay)
        }

        return minuteOfDay >= start || minuteOfDay < end
    }

    private func isAtHome(location: CLLocation, settings: TrackerSettings) -> Bool {
        let home = CLLocation(latitude: settings.homeLatitude, longitude: settings.homeLongitude)
        return location.distance(from: home) <= homeRadiusMeters
    }

    private func updateHomeRegion() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return
        }

        for region in manager.monitoredRegions where region.identifier == homeRegionIdentifier {
            manager.stopMonitoring(for: region)
        }

        let settings = settingsStore.settings
        let center = CLLocationCoordinate2D(latitude: settings.homeLatitude, longitude: settings.homeLongitude)
        let radius = min(homeRadiusMeters, manager.maximumRegionMonitoringDistance)

        guard radius > 0 else {
            return
        }

        let region = CLCircularRegion(center: center, radius: radius, identifier: homeRegionIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    private func applyHome(_ location: CLLocation, source: String) {
        settingsStore.settings.homeLatitude = location.coordinate.latitude
        settingsStore.settings.homeLongitude = location.coordinate.longitude
        updateHomeRegion()
        logStore.add(
            "Home set to \(source) location (\(formatCoordinate(location.coordinate.latitude)), \(formatCoordinate(location.coordinate.longitude)))."
        )
    }

    private func persistTrackingState() {
        defaults.set(isTracking, forKey: trackingStateKey)
    }

    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.5f", value)
    }

    private func formatMeters(_ value: CLLocationDistance) -> String {
        if value.isFinite {
            return String(Int(value.rounded()))
        }
        return "inf"
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        if value.isFinite {
            return String(Int(value.rounded()))
        }
        return "inf"
    }
}

extension LocationTracker: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logStore.add("Authorization changed: \(authorizationLabel(authorizationStatus)).")
        evaluateAuthorizationAndStartIfAllowed()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            processLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let location = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate
        )
        logStore.add("Visit event received.")
        processLocation(location, at: visit.arrivalDate)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == homeRegionIdentifier else {
            return
        }
        logStore.add("Entered home region.")
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == homeRegionIdentifier else {
            return
        }
        logStore.add("Exited home region.")
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if pendingSetHomeFromNextLocation {
            pendingSetHomeFromNextLocation = false
            lastError = "Unable to get current location for Home."
            logStore.add("Set Home failed: unable to fetch current location.")
            return
        }
        lastError = error.localizedDescription
        logStore.add("Location manager error: \(error.localizedDescription)")
    }

    private func authorizationLabel(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }
}
