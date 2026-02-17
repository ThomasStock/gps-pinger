import CoreLocation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum UploadError: Error {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)
}

struct LocationPingPayload: Encodable {
    let deviceId: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracyMeters: Double
    let speedMps: Double?
    let mode: String
    let batteryLevel: Float?
}

actor LocationUploader {
    private let session: URLSession
    private let encoder = JSONEncoder()

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = false
        session = URLSession(configuration: config)
        encoder.dateEncodingStrategy = .iso8601
    }

    func upload(
        location: CLLocation,
        mode: PingMode,
        settings: TrackerSettings,
        deviceId: String
    ) async throws {
        guard let endpoint = settings.endpointURL else {
            throw UploadError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !settings.bearerToken.isEmpty {
            request.setValue("Bearer \(settings.bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let payload = LocationPingPayload(
            deviceId: deviceId,
            timestamp: Date(),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            speedMps: location.speed >= 0 ? location.speed : nil,
            mode: mode.rawValue,
            batteryLevel: await currentBatteryLevel()
        )
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard 200 ..< 300 ~= http.statusCode else {
            throw UploadError.httpStatus(http.statusCode)
        }
    }

    private func currentBatteryLevel() async -> Float? {
        #if canImport(UIKit)
        return await MainActor.run {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let value = UIDevice.current.batteryLevel
            return value >= 0 ? value : nil
        }
        #else
        return nil
        #endif
    }
}
