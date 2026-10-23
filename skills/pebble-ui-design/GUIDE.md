# Pebble UI design guide

## 1. Establish the canvas

Emery: 200x228, rectangular, 64-color. Safe margin 2–5 px. Center (100, 114).
Gabbro: 260x260, round. Use the inscribed circle (center 130,130; radius ~130) and keep text inside ~180 px width near the top/bottom.

## 2. Allocate vertical bands

Example for a watchface:

```text
Battery/status:  Y=0..16
Time:            Y=32..96
Date:            Y=104..126
Data row:        Y=134..158
Footer/art:      Y=166..222
```

For each band compute:
- `bottom = y + h`; must be `< SCREEN_HEIGHT - margin`.
- `right = x + w`; must be `< SCREEN_WIDTH - margin`.

## 3. Position elements

- Center X: `x = (SCREEN_WIDTH - w) / 2`.
- Bottom-anchored: `y = SCREEN_HEIGHT - h - margin`.
- Right-anchored: `x = SCREEN_WIDTH - w - margin`.

## 4. GPath positioning

GPath points are **relative to the anchor** passed to `gpath_move_to`.

- If points span Y 0..-40 and the bottom should sit at Y=223, anchor Y = 223.
- If points span X -35..35 and the center should be X=100, anchor X = 100.
- Check negative extents against the anchor, not against 0.

## 5. Typography

Use system fonts where possible. Valid C font names/sizes are platform-specific; fetch the system-fonts page before using a combination you have not tested. For Alloy, invalid font name/size combinations can crash the JS VM at launch with a white screen.

Rules:
- Time is the hero: largest font, highest contrast.
- Date/data secondary: at least 14–18 px.
- Do not use more than 2 font families on one screen.
- Test the longest expected string (e.g., "Wed, Sep 30", "-18°").

## 6. Color

- Pick a 3–5 color palette from the 64-color set: background, primary text, secondary text, accent, shadow.
- Verify contrast for color and B&W platforms if targeting older watches.
- Use color to reinforce hierarchy, not to compensate for a crowded layout.

## 7. Animation budget

- Watchface: no continuous loop by default. Update on minute change; animate briefly after a tap or minute change.
- Subtle idle variation can be deterministic from the minute counter without a timer.
- Watchapp/game: ~33 ms timer only while visible; cancel on disappear/unload.
- Never animate on `SECOND_UNIT` unless the user explicitly asks for seconds.

## 8. Watchapp interaction map

For each screen list:
- Buttons and gestures,
- short/long/repeat behavior,
- destination window or state change,
- back behavior,
- what is persisted on exit.

Example:

| Screen | Select | Up | Down | Back |
|---|---|---|---|---|
| Menu | Open detail | Scroll up | Scroll down | Exit |
| Detail | Action | — | — | Pop |
| Game | Jump | Move left | Move right | Pause/exit |

## 9. Round and Quick View

- Gabbro: avoid corner-anchored text and rectangular frames; center content and test a round screenshot.
- Quick View: use the unobstructed area (`render.unobstructed` in Alloy; `UnobstructedArea` in C) and recompute layout on `resize`/appear. Do not assume the full 228 px height is always visible.

## 10. Self-check

- [ ] Every element has `bottom < screen height - margin`.
- [ ] Every element has `right < screen width - margin`.
- [ ] Center-aligned elements are actually centered.
- [ ] Longest strings fit.
- [ ] Every color pair is readable.
- [ ] Every watchapp interaction is reachable and has a back path.
- [ ] Animation stops when idle/hidden.
