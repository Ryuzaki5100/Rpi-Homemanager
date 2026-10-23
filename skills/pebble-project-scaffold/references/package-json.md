# package.json fields

```json
{
  "name": "my-app",
  "author": "Author",
  "version": "1.0.0",
  "keywords": ["pebble-app"],
  "private": true,
  "dependencies": {},
  "pebble": {
    "displayName": "My App",
    "uuid": "GENERATE-NEW-UUID",
    "sdkVersion": "3",
    "enableMultiJS": true,
    "targetPlatforms": ["emery"],
    "watchapp": { "watchface": false },
    "resources": { "media": [] }
  }
}
```

- `uuid`: RFC 4122 string.
- `targetPlatforms`: `aplite`, `basalt`, `chalk`, `diorite`, `emery`, `flint`, `gabbro`.
- `enableMultiJS`: `true` when `src/pkjs` exists.
- `capabilities`: `location`, `configurable` (and others only when used).
- `messageKeys`: array of strings; generated `MESSAGE_KEY_*` constants in C.
- `resources.media`: array of font/bitmap/resource descriptors.
- Alloy: add `"projectType": "moddable"`.
- Alloy networking: `"dependencies": { "@moddable/pebbleproxy": "^0.1.7" }`.
- Clay: `"dependencies": { "@rebble/clay": "^1.0.8" }`.

Never change `sdkVersion` from `"3"` for SDK 4.x projects.
