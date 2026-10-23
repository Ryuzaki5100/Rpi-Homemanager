# Round and Quick View

## Gabbro (260x260 round)

- Center: (130, 130)
- Keep primary text within roughly X 40..220 at the top/bottom; wider content can extend toward the middle.
- Avoid placing text in the four corners.
- Prefer concentric composition: rings, centered stacks, radial ticks.
- Test with `pebble install --emulator gabbro` and inspect a screenshot.

## Quick View

Timeline Quick View covers the bottom part of the screen.

C:
- Use `UnobstructedArea` callbacks (`unobstructed_area_service_subscribe`).
- Recompute layout when the obstructed bounds change.
- Do not assume `bounds.size.h` is fully visible.

Alloy:
- Use `render.unobstructed.width` / `.height`.
- Listen for `"resize"` and redraw.
- Clear with the full `render.width/height`, position with unobstructed values.

Test:

```bash
pebble emu-set-timeline-quick-view on --emulator emery
pebble screenshot --no-open --emulator emery quick-view.png
pebble emu-set-timeline-quick-view off --emulator emery
```
