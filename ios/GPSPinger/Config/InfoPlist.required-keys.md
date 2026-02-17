# Required Info.plist keys

Add these keys to the app target `Info.plist`:

- `NSLocationWhenInUseUsageDescription`: `We use your location to send GPS updates while the app is active.`
- `NSLocationAlwaysAndWhenInUseUsageDescription`: `We use your location in the background to send GPS updates.`
- `UIBackgroundModes`: include `location`
- `NSAppTransportSecurity` -> `NSAllowsLocalNetworking`: `true` (for local `http://localhost` mock endpoint)

If you use ATS-restricted endpoints (non-HTTPS), also configure `NSAppTransportSecurity` exceptions.

## Xcode target setup

- Signing & Capabilities:
  - Turn on `Background Modes`
  - Check `Location updates`
- Run on real iPhone; simulator background behavior is limited.
