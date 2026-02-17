import MapKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var tracker: LocationTracker

    @State private var homeMapPosition: MapCameraPosition = .automatic
    @State private var pendingHomeCoordinate: CLLocationCoordinate2D?
    @State private var selectingHomeFromMap = false
    @State private var endpointTestState: EndpointTestState = .idle

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
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Endpoint")

                            TextField("http://localhost:8787/ping", text: $settingsStore.settings.endpointURLString)
                                .urlInputStyle()
                                .appField()

                            SecureField("Bearer token (optional)", text: $settingsStore.settings.bearerToken)
                                .tokenInputStyle()
                                .appField()

                            HStack {
                                Spacer()

                                Button {
                                    Task {
                                        await testEndpoint()
                                    }
                                } label: {
                                    if endpointTestState.isTesting {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Testing...")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    } else {
                                        Label("Test", systemImage: "network")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(AppTheme.fieldBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                                )
                                .disabled(endpointTestState.isTesting)
                            }

                            if let message = endpointTestState.message {
                                Label(message, systemImage: endpointTestState.symbol)
                                    .font(.footnote)
                                    .foregroundStyle(endpointTestState.color)
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Home")

                            Map(position: $homeMapPosition, interactionModes: [.all]) {
                                if !selectingHomeFromMap {
                                    Marker("Home", coordinate: homeCoordinate)
                                }
                            }
                            .onMapCameraChange(frequency: .continuous) { context in
                                handleHomeMapCameraChange(context)
                            }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .center) {
                                if selectingHomeFromMap {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(AppTheme.primary)
                                        .offset(y: -16)
                                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .glassCard()

                        Button {
                            if selectingHomeFromMap, let pendingHomeCoordinate {
                                tracker.setHome(to: pendingHomeCoordinate)
                                updateHomeMapPosition()
                            } else {
                                tracker.setHomeToCurrentLocation()
                            }
                        } label: {
                            Text(selectingHomeFromMap ? "Set home to map center" : "Set home to current location")
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
                        .disabled(selectingHomeFromMap && pendingHomeCoordinate == nil)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Refresh intervals")

                            intervalSentenceRow(
                                selection: movingSecondsBinding,
                                options: Self.movingSecondOptions,
                                displayScale: .seconds,
                                suffix: "when on the move",
                            )

                            Divider()

                            intervalSentenceRow(
                                selection: stationaryDayMinutesBinding,
                                options: Self.stationaryMinuteOptions,
                                displayScale: .minutes,
                                suffix: "when not moving",
                            )

                            Divider()

                            intervalSentenceRow(
                                selection: homeOrNightMinutesBinding,
                                options: Self.homeOrNightMinuteOptions,
                                displayScale: .minutes,
                                suffix: "during night",
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
            .navigationTitle("Settings")
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
            .onChange(of: settingsStore.settings.endpointURLString) { _, _ in
                endpointTestState = .idle
            }
            .onChange(of: settingsStore.settings.bearerToken) { _, _ in
                endpointTestState = .idle
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
        pendingHomeCoordinate = nil
        selectingHomeFromMap = false
    }

    private func handleHomeMapCameraChange(_ context: MapCameraUpdateContext) {
        guard homeMapPosition.positionedByUser else {
            return
        }
        pendingHomeCoordinate = context.region.center
        selectingHomeFromMap = true
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
                closestOption(
                    to: Int(settingsStore.settings.movingIntervalSeconds.rounded()),
                    in: Self.movingSecondOptions
                )
            },
            set: { newValue in
                settingsStore.settings.movingIntervalSeconds = TimeInterval(newValue)
            }
        )
    }

    private var stationaryDayMinutesBinding: Binding<Int> {
        Binding(
            get: {
                closestOption(
                    to: settingsStore.settings.stationaryDayIntervalMinutes,
                    in: Self.stationaryMinuteOptions
                )
            },
            set: { newValue in
                settingsStore.settings.stationaryDayIntervalMinutes = newValue
            }
        )
    }

    private var homeOrNightMinutesBinding: Binding<Int> {
        Binding(
            get: {
                closestOption(
                    to: settingsStore.settings.homeOrNightIntervalMinutes,
                    in: Self.homeOrNightMinuteOptions
                )
            },
            set: { newValue in
                settingsStore.settings.homeOrNightIntervalMinutes = newValue
            }
        )
    }

    private static let movingSecondOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 300]
    private static let stationaryMinuteOptions = [1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180]
    private static let homeOrNightMinuteOptions = [2, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360]

    private func intervalSentenceRow(
        selection: Binding<Int>,
        options: [Int],
        displayScale: IntervalDisplayScale,
        suffix: String,
    ) -> some View {
        HStack(spacing: 8) {
            Text("Every")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)

            Picker("", selection: selection) {
                ForEach(options, id: \.self) { value in
                    Text(intervalLabel(for: value, scale: displayScale))
                        .tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .foregroundStyle(AppTheme.textPrimary)
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

    private func closestOption(to value: Int, in options: [Int]) -> Int {
        guard let closest = options.min(by: { abs($0 - value) < abs($1 - value) }) else {
            return value
        }
        return closest
    }

    private func intervalLabel(for value: Int, scale: IntervalDisplayScale) -> String {
        switch scale {
        case .seconds:
            if value >= 60, value.isMultiple(of: 60) {
                let minutes = value / 60
                return "\(minutes) min"
            }
            return "\(value) sec"
        case .minutes:
            if value >= 60 {
                let hours = value / 60
                let remMinutes = value % 60
                if remMinutes == 0 {
                    return "\(hours) hr"
                }
                return "\(hours) hr \(remMinutes) min"
            }
            return "\(value) min"
        }
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

    @MainActor
    private func testEndpoint() async {
        endpointTestState = .testing

        let endpoint = settingsStore.settings.endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty, let url = URL(string: endpoint) else {
            endpointTestState = .failure("Invalid endpoint URL.")
            return
        }

        let payload = LocationPingPayload(
            deviceId: "gps-pinger-endpoint-test",
            timestamp: Date(),
            latitude: 0,
            longitude: 0,
            horizontalAccuracyMeters: 100,
            speedMps: nil,
            mode: PingMode.stationaryDay.rawValue,
            batteryLevel: nil
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if !settingsStore.settings.bearerToken.isEmpty {
                request.setValue("Bearer \(settingsStore.settings.bearerToken)", forHTTPHeaderField: "Authorization")
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                endpointTestState = .failure("Invalid response from endpoint.")
                return
            }

            if 200 ..< 300 ~= http.statusCode {
                endpointTestState = .success("Test ping sent (HTTP \(http.statusCode)).")
            } else {
                endpointTestState = .failure("Endpoint returned HTTP \(http.statusCode).")
            }
        } catch {
            endpointTestState = .failure("Test failed: \(error.localizedDescription)")
        }
    }
}

private enum IntervalDisplayScale {
    case seconds
    case minutes
}

private enum EndpointTestState {
    case idle
    case testing
    case success(String)
    case failure(String)

    var isTesting: Bool {
        if case .testing = self {
            return true
        }
        return false
    }

    var message: String? {
        switch self {
        case .idle, .testing:
            return nil
        case .success(let message), .failure(let message):
            return message
        }
    }

    var symbol: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        case .idle, .testing:
            return "circle"
        }
    }

    var color: Color {
        switch self {
        case .success:
            return AppTheme.success
        case .failure:
            return AppTheme.danger
        case .idle, .testing:
            return AppTheme.textMuted
        }
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
            .foregroundStyle(AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            )
    }
}
