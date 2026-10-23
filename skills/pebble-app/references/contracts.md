# Phase artifact contracts

## `.pebble/state.json`
```json
{
  "name": "my-face",
  "displayName": "My Face",
  "author": "Author",
  "type": "watchface",
  "language": "C",
  "platforms": ["emery"],
  "phone": "none",
  "publish": false,
  "phase": "design",
  "gates": { "environment": false, "metadata": false, "design": false, "build": false, "visual": false, "interaction": false, "phone": false, "assets": false }
}
```

## `.pebble/design.md`
Must contain:
- target platform and dimensions,
- element table with `x`, `y`, `w`, `h`, bottom edge, right edge,
- palette and font names/sizes,
- update/animation timing,
- interaction map for watchapps,
- Quick View/round handling if relevant.

## Implementation output
- C: `src/c/main.c` (plus additional `.c`/`.h` files if needed), `wscript`, `package.json`, `resources/`.
- Alloy: `src/embeddedjs/main.js`, `src/embeddedjs/manifest.json`, `src/c/mdbl.c`, `package.json`, `wscript`.
- PKJS: `src/pkjs/index.js`, optional `src/pkjs/config.js`, matching `messageKeys`/`capabilities`.

## `.pebble/verification.md`
Record:
- build command and result,
- PBW path,
- screenshot path and checklist result (pass/fail per category),
- interaction commands and observed result,
- log errors or "none",
- phone test result or "n/a",
- final gate status.

## Delivery
`build/<name>.pbw`, `screenshot_emery.png`, optional `preview_emery.gif`, `icon_80x80.png`, `icon_144x144.png`.
