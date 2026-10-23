---
name: pebble-alloy-dev
description: Implements Pebble watchfaces and watchapps in Alloy (JavaScript on the watch via Moddable XS), including Poco drawing, Piu UI, watch events, custom fonts, sensors, storage, networking through pebbleproxy, App Messages, and Clay settings. Use when the chosen language is Alloy and the target is emery or gabbro.
---

# pebble-alloy-dev

Write complete Alloy apps for Pebble. Alloy runs JavaScript on the watch and supports **only emery and gabbro**.

## Step 0 — Read the Alloy guide first (mandatory)
`read <base-dir>/GUIDE.md` and then `references/alloy.md` before writing files. Read `references/watchapp.md` if the project is interactive.

## Core rules (always apply)
1. **Alloy only targets emery/gabbro.** If any older platform is required, switch to `pebble-c-dev`.
2. **`package.json` must have `"projectType": "moddable"`** and correct `watchapp.watchface`.
3. **`src/c/mdbl.c` is verbatim boilerplate** — do not modify it.
4. **Every extra JS module must be registered in `src/embeddedjs/manifest.json` `modules`.**
5. **Watchfaces use `watch.addEventListener("minutechange", draw)`**, not `secondchange`.
6. **Time events fire immediately on registration** — do not add a separate initial draw.
7. **Use validated system font name+size pairs** or register custom fonts in the manifest; invalid pairs can crash the VM with a white screen.
8. **`Location` is one-shot**: call `close()` after reading. `Battery` stays open.
9. **Networking requires `@moddable/pebbleproxy` + the pkjs shim** and a connected phone. Wait for `watch.connected.pebblekit === true`; retry transient first-fetch failures.
10. **Stop timers when done**; ~33 ms for animation, not 17 ms.
11. **Clay keys must match in three places**: `package.json.messageKeys`, `src/pkjs/config.js`, and watch-side `Message` keys.
12. **No `eval`/`Function`**; strict mode and frozen primordials.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Learn Alloy project anatomy and APIs | `references/alloy.md` | Full guide: Poco/Piu, sensors, storage, networking, Clay, FFI, gotchas |
| Build an interactive watchapp | `references/watchapp.md` | Buttons, UI patterns, app lifecycle |
| Start a project | `templates/alloy-package.json.template` | Alloy `package.json` |
| Boot the JS VM | `templates/alloy-mdbl.c` | Verbatim C stub |
| Register modules/fonts | `templates/alloy-manifest.json` | Moddable manifest |
| Start a watchface | `templates/alloy-watchface.js` | Poco watchface skeleton |
| Start a watchapp | `templates/alloy-watchapp.js` | Button/lifecycle skeleton |
| Add phone-side settings/network | `../pebble-phone/SKILL.md` | PKJS + Clay |

## Workflow
1. Read `GUIDE.md`, `references/alloy.md`, and `.pebble/design.md`.
2. Verify `package.json` is `projectType: moddable`, platforms emery/gabbro only.
3. Copy `alloy-mdbl.c` verbatim; write `src/embeddedjs/main.js` and `manifest.json`.
4. Register extra modules/fonts in the manifest.
5. Add `src/pkjs/index.js` + `config.js` through `pebble-phone` if networking/settings are needed.
6. Run `pebble package install @moddable/pebbleproxy` only if networking is used.
7. Build with `pebble build`; fix errors before emulator testing.

## Output
`src/embeddedjs/main.js`, `src/embeddedjs/manifest.json`, `src/c/mdbl.c` (verbatim), and optional `src/pkjs/`. No placeholder drawing or unregistered modules.

## Tools
`read`, `write`/`edit`, `bash` (`pebble build`, `pebble package install`), `glob`/`grep`.
