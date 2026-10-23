# Pebble phone-side guide (PebbleKit JS + Clay)

## 1. Architecture

```text
Watch (C or Alloy) <--AppMessage--> PKJS in the Pebble mobile app <--HTTP/geolocation--> Web
```

- PKJS files live in `src/pkjs/` and are bundled into the `.pbw`.
- The `pebble` tool runs a PKJS runtime next to the emulator, so most testing needs no phone.
- The Pebble mobile app runs the same JS on a real phone.

## 2. Lifecycle

```javascript
Pebble.addEventListener("ready", function () {
  // PKJS runtime is ready; request initial data.
});

Pebble.addEventListener("appmessage", function (e) {
  // e.payload contains keys from the watch.
});

Pebble.addEventListener("showConfiguration", function () {
  // Open the Clay settings URL (if not using Clay's built-in handling).
});

Pebble.addEventListener("webviewclosed", function (e) {
  // Parse e.response and send settings to the watch.
});
```

## 3. Sending data

```javascript
Pebble.sendAppMessage(
  { TEMPERATURE: 18, CONDITIONS: "Clear" },
  function () { console.log("sent"); },
  function (e) { console.log("send failed", e); }
);
```

- Keys are strings and must be in `messageKeys`.
- Watch side uses `MESSAGE_KEY_TEMPERATURE` / `MESSAGE_KEY_CONDITIONS`.
- Send only changed values when possible; avoid flooding.

## 4. Web data

- Use `XMLHttpRequest` or `fetch` (where available).
- Open-Meteo is free and keyless:
  `https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,weather_code`
- Handle HTTP errors, timeouts, missing location, and offline.
- Retry transient failures; do not leave the watch stuck on "loading" forever.

## 5. Location

- Requires `"capabilities": ["location"]`.
- `navigator.geolocation.getCurrentPosition(success, error)`.
- On the emulator, location may be unavailable; provide a fallback or a clear error state.

## 6. Clay settings

- `src/pkjs/config.js` exports the page schema.
- `src/pkjs/index.js` initializes `new Clay(config)`.
- Add every `messageKey` to `package.json`.
- Settings are stored by Clay/PKJS and sent to the watch on save.
- Test with `pebble emu-app-config`.

## 7. Alloy + pebbleproxy

If the watch is Alloy and uses `fetch`, add `@moddable/pebbleproxy` and the 3-line pkjs shim. If Clay is also used, forward only messages the proxy does not handle:

```javascript
if (moddableProxy.appMessageReceived(e)) return;
```

## 8. Packaging

```bash
pebble package install @rebble/clay
pebble package install @moddable/pebbleproxy
pebble build
```

`enableMultiJS` must be `true` in `package.json`.

## 9. Testing

```bash
pebble install --emulator emery
pebble logs --emulator emery
pebble emu-app-config
pebble send-app-message --int 1=42 --string 2=hello
```

For the real phone runtime, see `references/mobile-app-testing.md`.
