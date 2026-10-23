---
name: pebble-phone
description: Implements the phone-side half of a Pebble app using PebbleKit JS and Clay, including AppMessage dictionaries, web APIs (Open-Meteo/HTTP), geolocation, storage, settings pages, and testing with the emulator's PKJS runtime or the Pebble mobile app. Use when a watchface/watchapp needs weather, web data, location, configuration, or phone-side logic. This is bundled JavaScript inside the PBW, not a separate installed phone app.
---

# pebble-phone

Write `src/pkjs/` code that runs inside the Pebble mobile app and talks to the watch via AppMessage. Optionally add a Clay settings page.

## Step 0 — Read the phone guide first (mandatory)
`read <base-dir>/GUIDE.md`, then `references/pkjs.md` and `references/appmessage.md`. Read `references/clay.md` for settings and `references/mobile-app-testing.md` for phone-runtime testing.

## Core rules (always apply)
1. **PKJS is bundled in the PBW**; it is not a separately installed app. Do not scaffold a standalone Android/iOS app.
2. **Register watch callbacks before `app_message_open()`**.
3. **Every key must exist in `package.json.messageKeys`** and match C/PKJS/Clay exactly.
4. **Use `Pebble.sendAppMessage(dict, success, failure)`** and handle both callbacks.
5. **Never block**; use async callbacks/Promises and timeouts. Handle missing location/network.
6. **Clay keys must match in three places**: `package.json.messageKeys`, `config.js` `messageKey`, watch-side message keys.
7. **Clay needs `"capabilities": ["configurable"]`**; location needs `["location"]`.
8. **Do not put secrets in PKJS**; it ships in the PBW and is readable.
9. **Keep payloads small**; use compact keys and only send values the watch needs.
10. **Test with `pebble emu-app-config`** for Clay and `pebble send-app-message` for inbox handlers.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Understand the PKJS runtime and lifecycle | `references/pkjs.md` | `ready`, `appmessage`, config, logging |
| Design the message protocol | `references/appmessage.md` | Keys, dictionaries, ack/nack, buffers |
| Fetch weather/web data or location | `references/web-apis.md` | Open-Meteo, XHR/fetch, retries |
| Build a Clay settings page | `references/clay.md` | Config schema, persistence, watch sync |
| Test phone-side behavior | `references/mobile-app-testing.md` | `emu-app-config`, `--qemu`, mobile app, fake location |
| Decide whether a native app is needed | `references/native-options.md` | Scope boundary and PebbleKit links |
| Start a PKJS file | `templates/pkjs-index.js` | Minimal lifecycle skeleton |
| Start a weather fetch | `templates/pkjs-weather.js` | Open-Meteo + AppMessage |
| Start a Clay page | `templates/clay-config.js` | Settings schema |

## Workflow
1. Read `GUIDE.md` and the relevant references.
2. Define the message keys and add them to `package.json` (via `pebble-project-scaffold`).
3. Write `src/pkjs/index.js`; add `src/pkjs/config.js` for Clay.
4. Add `"capabilities"` and `"dependencies"` (`@rebble/clay`, `@moddable/pebbleproxy`) as needed.
5. Install packages with `pebble package install` if required.
6. Build, install, and test: `pebble emu-app-config`, `pebble send-app-message`, `pebble logs`.
7. Hand back to `pebble-build-test` for the full gate.

## Output
`src/pkjs/index.js` plus optional `src/pkjs/config.js`; updated `package.json` message keys/capabilities/dependencies. No native Android/iOS project.

## Tools
`read`, `write`/`edit`, `bash` (`pebble package install`, build/test), `question` (settings/data schema).
