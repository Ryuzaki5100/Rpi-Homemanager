# Clay settings

## Files

- `src/pkjs/config.js` — page schema.
- `src/pkjs/index.js` — `new Clay(config)`.
- `package.json` — `"capabilities": ["configurable"]`, `messageKeys`, and `"@rebble/clay"` dependency.

## Minimal config

```javascript
module.exports = [
  { "type": "heading", "defaultValue": "Settings" },
  { "type": "toggle", "messageKey": "ShowDate", "label": "Show date", "defaultValue": true },
  { "type": "color", "messageKey": "BackgroundColor", "label": "Background", "defaultValue": "0x000000" },
  { "type": "submit", "defaultValue": "Save" }
];
```

## Watch side

- C: read `MESSAGE_KEY_SHOWDATE` / `MESSAGE_KEY_BACKGROUNDCOLOR`.
- Alloy: `Message` keys must match exactly.
- Colors arrive as 24-bit ints; split with `(v >> 16) & 0xFF`, etc.

## Three-place key check

1. `package.json.messageKeys`
2. `src/pkjs/config.js` `messageKey`
3. watch-side `MESSAGE_KEY_*` or Alloy `Message` key

A mismatch silently drops the setting.

## Testing

```bash
pebble emu-app-config
```

Change a value, save, and confirm the watch updates. On a real phone, the settings page opens from the Pebble app's app settings.
