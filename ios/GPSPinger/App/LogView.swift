import SwiftUI

struct LogView: View {
    @ObservedObject var logStore: AppLogStore

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.pageBackgroundTop, AppTheme.pageBackgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if logStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No logs yet",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text("Ping attempts and state changes will appear here.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(logStore.entries.reversed())) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textMuted)
                                    Text(entry.message)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: clearButtonPlacement) {
                    Button("Clear") {
                        logStore.clear()
                    }
                    .disabled(logStore.entries.isEmpty)
                }
            }
        }
    }

    private var clearButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}
