import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var tracker: LocationTracker
    @ObservedObject var logStore: AppLogStore

    var body: some View {
        TabView {
            TrackerView(settingsStore: settingsStore, tracker: tracker)
                .tabItem {
                    Label("Tracker", systemImage: "location.fill")
                }

            LogView(logStore: logStore)
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
        }
        .fontDesign(.rounded)
        .tint(AppTheme.primary)
    }
}
