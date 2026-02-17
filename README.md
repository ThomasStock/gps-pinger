# GPS Pinger (iOS)

Battery-aware iPhone app that sends GPS pings to a configurable HTTP endpoint.

Built with SwiftUI + CoreLocation. Designed to ping more while moving, and less when at home or during night hours.

## Current features

- Configurable endpoint URL and optional bearer token.
- Default endpoint: `http://localhost:8787/ping`.
- Start/Stop tracking control.
- Background-capable location tracking setup:
  - significant location changes
  - visits
  - home-region monitoring (100 m fixed radius)
  - continuous updates tuned by active mode
- Adaptive ping policy:
  - **moving**: shorter interval, tighter accuracy/filter
  - **stationary daytime**: medium interval
  - **home or night**: longest interval, low-power tuning
- Home map view with marker.
- `Set home to current location` button.
  - Uses cached location when available.
  - Falls back to one-shot location request when needed.
- `Log` tab with timestamped app events and ping attempts.
- Styled, minimal UI (Tracker + Log tabs).

## Adaptive behavior

Mode selection logic:

1. If user is moving (speed/estimated speed threshold), mode = `moving`.
2. Else if user is at home (<= 100 m) or within night window, mode = `homeOrNight`.
3. Else mode = `stationaryDay`.

Ping is sent only when both are true:

- minimum time interval reached
- minimum distance moved reached

## Ping payload

`POST` body fields:

- `deviceId`
- `timestamp` (ISO-8601)
- `latitude`
- `longitude`
- `horizontalAccuracyMeters`
- `speedMps` (nullable)
- `mode` (`moving` | `stationaryDay` | `homeOrNight`)
- `batteryLevel` (nullable)

## Local mock server

A local mock server is included for development.

File: `scripts/mock_server.py`

Run:

```bash
python3 scripts/mock_server.py
```

Endpoints:

- `POST /ping`
- `GET /logs`
- `GET /health`

Default bind: `127.0.0.1:8787`

## Requirements

- macOS with Xcode installed
- `xcodegen` installed (`brew install xcodegen`)
- iOS Simulator (or physical iPhone for real background validation)

## Build and run (CLI)

```bash
xcodegen generate
xcodebuild -project GPSPinger.xcodeproj -scheme GPSPinger -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Install + launch on currently booted simulator:

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug-iphonesimulator/GPSPinger.app' -print -quit)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.thomas.gpspinger
```

## Simulator location spoofing

Set fixed location:

```bash
xcrun simctl location booted set 37.3349,-122.0090
```

Simulate movement:

```bash
xcrun simctl location booted start --interval=1 \
  37.3349,-122.0090 37.3318,-122.0312 37.3270,-122.0320
```

Clear simulated location:

```bash
xcrun simctl location booted clear
```

Also available via Simulator UI: `Features -> Location`.

## Permissions and background mode

Configured in `ios/GPSPinger/Config/Info.plist`:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes = [location]`
- `NSAllowsLocalNetworking = true` (for local mock server)

## Project structure

- `ios/GPSPinger/App` - SwiftUI screens + app wiring
- `ios/GPSPinger/Tracking` - location tracker + adaptive policy
- `ios/GPSPinger/Networking` - HTTP upload actor
- `ios/GPSPinger/Services` - settings + in-app log store
- `ios/GPSPinger/Models` - tracker settings model
- `scripts/mock_server.py` - local mock endpoint
- `project.yml` - XcodeGen source project definition

## Notes

- iOS background execution is event-driven. You cannot rely on exact timer cadence while backgrounded.
- Real behavior must be tested on device while moving and with different power/network states.
