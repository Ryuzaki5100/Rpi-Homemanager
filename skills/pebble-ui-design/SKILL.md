---
name: pebble-ui-design
description: Produces a pixel-accurate Pebble design specification for a watchface or watchapp on emery, gabbro, or older platforms, including element positions, edge math to prevent cropping, color palette, system/custom fonts, animation budget, Quick View/round behavior, and watchapp interaction maps. Use before implementing a Pebble UI or when a screenshot shows cropping, poor contrast, or layout drift.
---

# pebble-ui-design

Turn a visual/behavior request into a concrete layout the implementation skills can code without guessing.

## Step 0 — Read the design guide first (mandatory)
`read <base-dir>/GUIDE.md` before designing. Use `references/emery-layout.md` for the default 200x228 grid and `references/round-and-quick-view.md` when targeting gabbro or adding Timeline.

## Core rules (always apply)
1. **Calculate every element's bottom and right edge**; nothing may exceed the screen or safe margin.
2. **Use `bounds.size` in generated code**, not hardcoded dimensions, even when the design targets emery.
3. **Emery safe area:** X 2–197, Y 2–225. Center is (100, 114).
4. **Gabbro is round:** keep content inside the inscribed circle; do not reuse rectangular edge coordinates.
5. **Battery budget:** watchfaces update on minute boundaries; animations only on tap or briefly after a minute change.
6. **Watchfaces have no buttons**; design tap/accelerometer interactions only.
7. **Watchapps must map every button path** (back/up/select/down, short/long/repeat as needed).
8. **Contrast first:** every text color must be readable against its background on the 64-color palette.
9. **No unplanned overflow:** if the design cannot fit, change the composition, not the screen.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Run the full design method | `GUIDE.md` | Layout, palette, typography, animation, interactions |
| Use the emery 200x228 grid | `references/emery-layout.md` | Safe zones, common layout bands, math |
| Target gabbro or handle Quick View | `references/round-and-quick-view.md` | Round-safe layout and unobstructed area |
| Pick font sizes and colors | `references/typography-color.md` | System fonts, sizes, palette rules |
| Design watchapp navigation | `references/watchapp-ux.md` | Button mapping, window stack, menus |
| Write the spec | `templates/design-spec.md` | Required design document shape |

## Workflow
1. Read `GUIDE.md`.
2. Confirm platform, face/app, and visual intent.
3. Choose layout bands and compute `x/y/w/h`, bottom edge, right edge for every element.
4. Choose fonts/colors; verify all font name+size combinations are valid.
5. Define update/animation timing and interaction map.
6. Write `.pebble/design.md` from `templates/design-spec.md`.
7. Self-check: no negative offsets, no edge >= screen, every interaction reachable.
8. Hand off to `pebble-c-dev` or `pebble-alloy-dev`.

## Output
`.pebble/design.md` with the complete element table and behavior map. No source code.

## Tools
`read`, `write`/`edit`, `question` (visual intent), `bash` (optional layout arithmetic).
