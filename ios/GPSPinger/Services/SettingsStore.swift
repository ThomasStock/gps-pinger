import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: TrackerSettings {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let settingsKey = "gps_pinger.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard
            let raw = defaults.data(forKey: settingsKey),
            let decoded = try? JSONDecoder().decode(TrackerSettings.self, from: raw)
        else {
            settings = .defaults
            return
        }

        var loaded = decoded
        if loaded.endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines) == "https://example.com/location" {
            loaded.endpointURLString = TrackerSettings.defaults.endpointURLString
        }
        settings = loaded
        if loaded != decoded {
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: settingsKey)
    }
}
