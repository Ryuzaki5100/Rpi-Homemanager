# PebbleKit JS runtime

## Events

| Event | When |
|---|---|
| `ready` | PKJS runtime is ready; fetch initial data |
| `appmessage` | Watch sent a dictionary |
| `showConfiguration` | User opened settings |
| `webviewclosed` | Settings page closed |

## Logging

`console.log` appears in `pebble logs --emulator emery` (or on-device logs). Keep logs concise and free of secrets.

## Storage

Use `localStorage` for small strings (settings, cached values). It is per-app. JSON-stringify objects.

## Networking

`XMLHttpRequest` is universally available. `fetch` availability depends on the runtime; prefer XHR for C/PKJS compatibility. Always set a timeout/retry path.

## Sending

`Pebble.sendAppMessage(dict, ack, nack)`. The watch must have matching `messageKeys`. Use compact keys.

## Configuration

Clay is the standard settings framework: `@rebble/clay`. It handles the settings page, persistence, and sending values to the watch. A manual `showConfiguration`/`webviewclosed` flow is possible but unnecessary unless you need custom HTML.

## Gotchas

- `ready` can fire before the phone has network/location; do not assume success.
- `Pebble.sendAppMessage` can fail if the watchapp is not running or the payload is too large.
- PKJS is bundled and readable; never ship API secrets.
- On the emulator, geolocation may be mocked/unavailable.
