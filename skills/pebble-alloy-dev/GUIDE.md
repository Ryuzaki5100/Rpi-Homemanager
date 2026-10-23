# Alloy implementation guide

## 1. Project shape

```text
project/
  package.json              # projectType: moddable
  wscript                   # stock
  src/c/mdbl.c              # verbatim VM boot stub
  src/embeddedjs/
    main.js                 # all watch logic
    manifest.json           # modules/fonts/FFI
    assets/                 # optional custom fonts
  src/pkjs/                 # only for networking/Clay
    index.js
    config.js
```

## 2. Watchface vs watchapp

- Watchface: `"watchapp": { "watchface": true }`; use `watch.addEventListener("minutechange", draw)`.
- Watchapp: `"watchface": false`; import `Button from "pebble/button"` and handle `onPush(down, type)`.

## 3. Draw loop

Poco:

```javascript
import Poco from "commodetto/Poco";
const render = new Poco(screen);
function draw() {
  render.begin();
  render.fillRectangle(bg, 0, 0, render.width, render.height);
  // draw...
  render.end();
}
watch.addEventListener("minutechange", draw);
```

- Reuse color/font objects.
- `render.begin(x,y,w,h)` clips for speed.
- Clear the full screen each frame.
- Handlers may be called without an event; use `event?.date ?? lastDate`.

## 4. Events and input

- `minutechange`, `hourchange`, `connected`, `resize` (Quick View).
- Watchface Up/Down are timeline-reserved; use accelerometer taps.
- Watchapp buttons via `pebble/button`.
- Touch: feature-detect `device.sensor.Touch`.

## 5. Fonts

- Use valid system font name+size pairs (see `references/alloy.md`).
- Custom TTF: put in `src/embeddedjs/assets/`, declare in `manifest.json` `resources["*-alpha"]`, load with `parseBMF`/`parseRLE`.
- Invalid combinations can white-screen the VM with no log error.

## 6. Networking

```bash
pebble package install @moddable/pebbleproxy
```

`src/pkjs/index.js`:

```javascript
const moddableProxy = require("@moddable/pebbleproxy");
Pebble.addEventListener("ready", moddableProxy.readyReceived);
Pebble.addEventListener("appmessage", moddableProxy.appMessageReceived);
```

Then use `fetch`/`WebSocket` on the watch. Wait for `watch.connected.pebblekit`; retry a failed first fetch. If `fetch` crashes, use the raw `device.network.https.io` pattern in `references/alloy.md`.

## 7. Storage

- `localStorage`: strings only; `JSON.stringify`/`parse` with try/catch.
- `device.keyValue` for structured values; `device.files` for binary.

## 8. Settings (Clay)

- `src/pkjs/config.js` defines the page.
- `package.json` needs `messageKeys` and `"capabilities": ["configurable"]`.
- Watch side: `import Message from "pebble/message"` with the same keys.
- If pebbleproxy is present, forward only app messages it does not handle:
  `if (moddableProxy.appMessageReceived(e)) return;`

## 9. Build and test

```bash
pebble build
pebble install --emulator emery
pebble logs --emulator emery
pebble screenshot --no-open --emulator emery shot.png
```

Alloy build runs `mcrun`; the SDK toolchain must be present (Nix setup provides it).
