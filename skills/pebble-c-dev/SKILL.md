---
name: pebble-c-dev
description: Implements Pebble watchfaces and watchapps in C, including drawing, GPath, animations, tick timers, button click handlers, window stacks, MenuLayer/ActionBar/ScrollLayer, game loops, persistence, wakeups, app glances, and background workers. Use when the chosen language is C for a Pebble face or app.
---

# pebble-c-dev

Write complete, buildable C for Pebble. Pick the watchface or watchapp mode, follow the design spec, and satisfy the constraints.

## Step 0 — Read the mode guide first (mandatory)
`read <base-dir>/GUIDE.md`, then read `references/watchface.md` for faces or `references/watchapp.md` for apps.

## Core rules (always apply)
1. **No floating point.** Use `sin_lookup`/`cos_lookup`, `DEG_TO_TRIGANGLE`, and integer math.
2. **Watchfaces use `MINUTE_UNIT`** unless the user explicitly asks for seconds.
3. **Watchfaces have no buttons**; only accelerometer taps.
4. **Watchapps use the `window_set_click_config_provider` + click APIs**; BACK is system-reserved for long-press exit.
5. **Games use a ~33 ms AppTimer** and cancel it when the window disappears/unloads.
6. **Use `layer_get_bounds()`**, never hardcoded screen dimensions.
7. **Register AppMessage callbacks before `app_message_open()`**.
8. **Destroy every resource** created in `window_load` in the matching `unload` handler.
9. **Pre-allocate long-lived GPaths/fonts/layers**; small short-lived paths may be created in draw.
10. **Do not leave timers or services running when idle.**

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Understand the full C workflow | `GUIDE.md` | Mode selection, project structure, build loop |
| Build a watchface | `references/watchface.md` | Tick timer, time/date, battery, weather display |
| Build a watchapp | `references/watchapp.md` | Click config, window stack, menus, app-only capabilities |
| Draw shapes/text/paths | `references/drawing.md` | Graphics primitives, GPath, colors, performance |
| Animate | `references/animation.md` | Frame loops, path animation, collision, easing |
| Build a game | `references/games.md` | Game loop, raw input, state machine, persistence |
| Use persistence/wakeup/glance/worker | `references/services.md` | App-only services and memory limits |
| Start from a watchface | `templates/static-watchface.c` | Static/analog skeleton |
| Start from an animated face | `templates/animated-watchface.c` | Animation skeleton |
| Start from a weather face | `templates/weather-watchface.c` | AppMessage + weather skeleton |
| Start from a watchapp | `templates/watchapp.c` | Buttons + window stack skeleton |
| Start from a game | `templates/game.c` | Timer loop + raw input skeleton |

## Workflow
1. Read `GUIDE.md` and the mode reference.
2. Read `.pebble/design.md`; do not guess positions.
3. Copy the closest template to `src/c/main.c` (or split into multiple files under `src/c/`).
4. Implement `main()`, `init()`, `deinit()`, and window load/unload handlers.
5. Add AppMessage only if `pebble-phone` is in the plan; register callbacks before opening.
6. Compile with `pebble build` (the build/test skill owns the emulator loop unless asked to self-check).
7. Fix compiler errors; never silence them with casts or removed features.

## Output
Complete `src/c/main.c` plus any additional C files/headers. No TODOs, no placeholder drawing, no uninitialized handlers.

## Tools
`read`, `write`/`edit`, `bash` (`pebble build` for quick compiler feedback), `glob`/`grep`.
