import MapKit
import SwiftUI

struct TrackerView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var tracker: LocationTracker

    @State private var homeMapPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.pageBackgroundTop, AppTheme.pageBackgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            if tracker.isTracking {
                                tracker.stopTracking()
                            } else {
                                tracker.startTracking()
                            }
                        } label: {
                            Text(tracker.isTracking ? "Stop tracking" : "Start tracking")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.buttonText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(tracker.isTracking ? AppTheme.danger : AppTheme.primary)
                                )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: AppTheme.buttonShadow, radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity)

                        if let lastPingAt = tracker.lastPingAt {
                            Text("Last ping: \(lastPingAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textMuted)
                        }

                        if let lastError = tracker.lastError {
                            Text(lastError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Endpoint")

                            TextField("http://localhost:8787/ping", text: $settingsStore.settings.endpointURLString)
                                .urlInputStyle()
                                .appField()

                            SecureField("Bearer token (optional)", text: $settingsStore.settings.bearerToken)
                                .tokenInputStyle()
                                .appField()
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Home")

                            Map(position: $homeMapPosition, interactionModes: [.all]) {
                                Marker("Home", coordinate: homeCoordinate)
                            }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .glassCard()

                        Button {
                            tracker.setHomeToCurrentLocation()
                        } label: {
                            Text("Set home to current location")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.secondaryButtonText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.secondaryButtonFill)
                                )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Refresh intervals")

                            intervalSentenceRow(
                                valueLabel: "\(movingSecondsBinding.wrappedValue) sec",
                                suffix: "when on the move",
                                onDecrement: { movingSecondsBinding.wrappedValue -= 5 },
                                onIncrement: { movingSecondsBinding.wrappedValue += 5 },
                                canDecrement: movingSecondsBinding.wrappedValue > 5,
                                canIncrement: movingSecondsBinding.wrappedValue < 300
                            )

                            Divider()

                            intervalSentenceRow(
                                valueLabel: "\(settingsStore.settings.stationaryDayIntervalMinutes) min",
                                suffix: "when not moving",
                                onDecrement: {
                                    settingsStore.settings.stationaryDayIntervalMinutes = max(
                                        1,
                                        settingsStore.settings.stationaryDayIntervalMinutes - 1
                                    )
                                },
                                onIncrement: {
                                    settingsStore.settings.stationaryDayIntervalMinutes = min(
                                        180,
                                        settingsStore.settings.stationaryDayIntervalMinutes + 1
                                    )
                                },
                                canDecrement: settingsStore.settings.stationaryDayIntervalMinutes > 1,
                                canIncrement: settingsStore.settings.stationaryDayIntervalMinutes < 180
                            )

                            Divider()

                            intervalSentenceRow(
                                valueLabel: "\(settingsStore.settings.homeOrNightIntervalMinutes) min",
                                suffix: "during night",
                                onDecrement: {
                                    settingsStore.settings.homeOrNightIntervalMinutes = max(
                                        1,
                                        settingsStore.settings.homeOrNightIntervalMinutes - 1
                                    )
                                },
                                onIncrement: {
                                    settingsStore.settings.homeOrNightIntervalMinutes = min(
                                        360,
                                        settingsStore.settings.homeOrNightIntervalMinutes + 1
                                    )
                                },
                                canDecrement: settingsStore.settings.homeOrNightIntervalMinutes > 1,
                                canIncrement: settingsStore.settings.homeOrNightIntervalMinutes < 360
                            )
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Day window")

                            HStack(spacing: 8) {
                                Text("From")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                DatePicker("", selection: dayStartBinding, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)

                                Text("until")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                DatePicker("", selection: dayEndBinding, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .glassCard()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("GPS Pinger")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                updateHomeMapPosition()
            }
            .onChange(of: settingsStore.settings.homeLatitude) { _, _ in
                updateHomeMapPosition()
            }
            .onChange(of: settingsStore.settings.homeLongitude) { _, _ in
                updateHomeMapPosition()
            }
        }
    }

    private var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: settingsStore.settings.homeLatitude,
            longitude: settingsStore.settings.homeLongitude
        )
    }

    private func updateHomeMapPosition() {
        let region = MKCoordinateRegion(
            center: homeCoordinate,
            latitudinalMeters: 900,
            longitudinalMeters: 900
        )
        homeMapPosition = .region(region)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private var dayStartBinding: Binding<Date> {
        Binding(
            get: {
                dateFromMinutes(settingsStore.settings.dayStartsMinutesFromMidnight)
            },
            set: { newValue in
                settingsStore.settings.dayStartsMinutesFromMidnight = minuteOfDay(newValue)
            }
        )
    }

    private var dayEndBinding: Binding<Date> {
        Binding(
            get: {
                dateFromMinutes(settingsStore.settings.dayEndsMinutesFromMidnight)
            },
            set: { newValue in
                settingsStore.settings.dayEndsMinutesFromMidnight = minuteOfDay(newValue)
            }
        )
    }

    private var movingSecondsBinding: Binding<Int> {
        Binding(
            get: {
                Int(settingsStore.settings.movingIntervalSeconds.rounded())
            },
            set: { newValue in
                let clamped = min(max(5, newValue), 300)
                settingsStore.settings.movingIntervalSeconds = TimeInterval(clamped)
            }
        )
    }

    private func intervalSentenceRow(
        valueLabel: String,
        suffix: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void,
        canDecrement: Bool,
        canIncrement: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text("Every")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(!canDecrement)
                .foregroundStyle(canDecrement ? AppTheme.textPrimary : AppTheme.textMuted)

                Text(valueLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(minWidth: 72)

                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(!canIncrement)
                .foregroundStyle(canIncrement ? AppTheme.textPrimary : AppTheme.textMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.fieldBackground)
            )

            Text(suffix)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let safe = min(max(0, minutes), (24 * 60) - 1)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .minute, value: safe, to: startOfDay) ?? Date()
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((comps.hour ?? 0) * 60) + (comps.minute ?? 0)
    }
}

private extension View {
    @ViewBuilder
    func urlInputStyle() -> some View {
        #if os(iOS)
        keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func tokenInputStyle() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    func appField() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.fieldBackground)
            )
    }
}
