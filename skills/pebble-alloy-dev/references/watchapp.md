# Alloy watchapp patterns

## Buttons

```javascript
import Button from "pebble/button";

new Button({
  types: ["select", "up", "down", "back"],
  onPush(down, type) {
    if (down && type === "select") action();
  }
});
```

- `down` is 1 on press, 0 on release.
- Watchapp Up/Down are usable; watchface Up/Down are timeline-reserved.
- BACK pops the app; long-press exits.

## UI

- **Poco** for pixel-level custom drawing (games, animated screens).
- **Piu** for declarative components (`Application`, `Content`, `Label`, `Container`, `Skin`).
- **Port** bridges Piu layout with custom Poco drawing when needed.
- Use `device.sensor.Touch` only after feature-detecting it.

## Lifecycle

- `watch.launch` gives the launch reason.
- Clean up intervals in the app's teardown path.
- Persist settings/state in `localStorage` or `device.keyValue`.
- `watch.light(true/false)` for backlight; `import Vibes from "pebble/vibes"` for haptics.

## Animation

- `setInterval(draw, 33)` ≈ 30 fps.
- Use `Timeline`/easing for UI transitions (200–500 ms).
- Stop timers when the animation completes or the screen is hidden.

## Settings + AppMessage

- Use `pebble/message` for watch-side message handling.
- Keep `package.json.messageKeys`, `config.js` `messageKey`s, and watch `keys` identical.
- Test with `pebble emu-app-config` and `pebble send-app-message`.
