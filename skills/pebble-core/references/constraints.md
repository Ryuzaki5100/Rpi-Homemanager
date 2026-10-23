# Non-negotiable Pebble constraints

## Battery
- Watchfaces: `tick_timer_service_subscribe(MINUTE_UNIT, handler)`. Never `SECOND_UNIT` unless explicitly requested.
- Brief animations: `app_timer_register()` at ~50 ms, then stop.
- Games: ~33 ms frame timer only while the game window is visible; cancel in `disappear`/`unload`.
- Do not leave repeating timers running when the app is not visible.

## C memory and math
- No floating point. Use `sin_lookup` / `cos_lookup` with `TRIG_MAX_ANGLE` and `DEG_TO_TRIGANGLE`.
- Pre-allocate long-lived `GPath`, fonts, and layers in `window_load`; destroy them in `unload`.
- Small short-lived paths (3–6 points) may be created/destroyed in a draw callback.
- Check pointers before use; modulo counters before they overflow.

## Metadata
- `pebble.sdkVersion` is always `"3"`, including SDK 4.x projects.
- Watchface: `"watchapp": { "watchface": true }`; watchapp: `false`.
- Alloy: `"projectType": "moddable"`, `targetPlatforms` subset of `["emery", "gabbro"]`.
- `messageKeys` must contain every key used by C, PKJS, and Clay.
- Clay settings need `"capabilities": ["configurable"]`; location needs `["location"]`.

## AppMessage
- Register inbox/dropbox callbacks **before** `app_message_open()`.
- Use `app_message_inbox_size_maximum()` / `app_message_outbox_size_maximum()` for larger payloads.
- PKJS is bundled in the PBW; it is not a separately installed phone app.

## Drawing
- The C SDK has no ellipse primitive. Draw rings with two filled circles (outer color, inner background) or a 1 px `graphics_draw_circle`.
- Use `graphics_fill_radial` for arcs/sectors; `graphics_draw_arc` for outlines.
- Clear the full screen before redrawing an animated frame.
