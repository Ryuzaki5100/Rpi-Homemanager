# Native companion apps: scope

This suite intentionally does **not** generate native Android or iOS companion apps.

## When PKJS is enough

- Weather/web data, geolocation, settings, AppMessage, timeline local pins, storage.
- Runs inside the Pebble mobile app; bundled in the PBW; no separate install.

## When a native app is required

A native app is only needed when the phone side must use platform APIs that PKJS cannot reach, for example deep OS integrations, background services, or custom BLE work.

- **Android**: modern [PebbleKitAndroid2](https://github.com/pebble-dev/PebbleKitAndroid2) (`io.rebble.pebblekit2:client`), Kotlin/Gradle. Add `pebble.companionApp.android` metadata to the watchapp's `package.json`.
- **iOS**: PebbleKit iOS is discontinued; do not plan a new iOS companion.

Native companion support is a separate project; do not scaffold it from `pebble-phone`.
