# Resources, capabilities, and keys

## Fonts
```json
{ "type": "font", "name": "FONT_CUSTOM_24", "file": "fonts/Custom.ttf", "compatibility": "2.7" }
```
- Use system fonts first. Add custom fonts only when the design requires them.
- Alloy custom fonts are declared in `src/embeddedjs/manifest.json` (`resources["*-alpha"]`).

## Bitmaps
```json
{ "type": "bitmap", "name": "IMAGE_ICON", "file": "images/icon.png" }
```
- Prefer 1-bit/PNG8 for B&W platforms; test on emery.

## Message keys
- Add every key used by PKJS, C, and Clay to `pebble.messageKeys`.
- C accessor: `MESSAGE_KEY_<NAME>`.
- Clay `messageKey` strings must match exactly.
- Key names are case-sensitive.

## Capabilities
- `location`: PKJS `navigator.geolocation` / Alloy Location sensor.
- `configurable`: Clay settings page.
- Add only what the app uses.

## Alloy manifest
Every extra JS module must be listed under `modules`; custom fonts under `resources`. An unregistered module fails at runtime.
