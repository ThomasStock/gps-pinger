import SwiftUI

struct TrackerView: View {
    @ObservedObject var tracker: LocationTracker

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.pageBackgroundTop, AppTheme.pageBackgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: 12)

                    Button {
                        if tracker.isTracking {
                            tracker.stopTracking()
                        } else {
                            tracker.startTracking()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(tracker.isTracking ? AppTheme.danger : AppTheme.primary)

                            Circle()
                                .stroke(Color.white.opacity(0.28), lineWidth: 2)
                                .padding(10)

                            VStack(spacing: 8) {
                                Image(systemName: tracker.isTracking ? "stop.fill" : "location.fill")
                                    .font(.system(size: 42, weight: .bold))
                                Text(tracker.isTracking ? "Stop" : "Start")
                                    .font(.title2.weight(.bold))
                                Text("tracking")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(AppTheme.buttonText)
                        }
                        .frame(width: 240, height: 240)
                    }
                    .buttonStyle(RoundTrackingButtonStyle())
                    .animation(.easeInOut(duration: 0.2), value: tracker.isTracking)
                    .accessibilityLabel(tracker.isTracking ? "Stop tracking" : "Start tracking")

                    LastPingLabel(lastPingAt: tracker.lastPingAt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textMuted)

                    if let lastError = tracker.lastError {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                            .padding(.horizontal, 16)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("GPS Pinger")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct RoundTrackingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .shadow(
                color: AppTheme.buttonShadow.opacity(configuration.isPressed ? 0.08 : 0.20),
                radius: configuration.isPressed ? 9 : 18,
                x: 0,
                y: configuration.isPressed ? 4 : 10
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct LastPingLabel: View {
    let lastPingAt: Date?
    private let formatter = RelativeDateTimeFormatter()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text("Last pinged \(lastPingText(relativeTo: context.date))")
        }
    }

    private func lastPingText(relativeTo date: Date) -> String {
        guard let lastPingAt else {
            return "never"
        }

        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastPingAt, relativeTo: date)
    }
}
