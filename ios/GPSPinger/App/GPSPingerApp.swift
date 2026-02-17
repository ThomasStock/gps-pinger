import SwiftUI

@main
struct GPSPingerApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var logStore: AppLogStore
    @StateObject private var tracker: LocationTracker

    init() {
        let settingsStore = SettingsStore()
        let logStore = AppLogStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _logStore = StateObject(wrappedValue: logStore)
        _tracker = StateObject(wrappedValue: LocationTracker(settingsStore: settingsStore, logStore: logStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settingsStore: settingsStore, tracker: tracker, logStore: logStore)
        }
    }
}
