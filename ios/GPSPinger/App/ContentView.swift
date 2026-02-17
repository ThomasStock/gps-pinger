import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var tracker: LocationTracker
    @ObservedObject var logStore: AppLogStore

    var body: some View {
        TabView {
            TrackerView(tracker: tracker)
                .tabItem {
                    Label("Tracker", systemImage: "location.fill")
                }

            SettingsView(settingsStore: settingsStore, tracker: tracker)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }

            LogView(logStore: logStore)
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
        }
        .fontDesign(.rounded)
        .tint(AppTheme.primary)
        .toolbarBackground(AppTheme.tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
