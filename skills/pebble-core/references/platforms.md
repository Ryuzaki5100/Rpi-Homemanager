# Pebble platform matrix

| Platform | Model | Resolution | Shape | Colors | App memory |
|---|---|---|---|---|---|
| **emery** | Pebble Time 2 | **200x228** | Rect | 64-color | 128 KB |
| gabbro | Pebble Round 2 | 260x260 | Round | 64-color | 128 KB |
| basalt | Pebble Time | 144x168 | Rect | 64-color | 64 KB |
| chalk | Pebble Time Round | 180x180 | Round | 64-color | 64 KB |
| aplite | Pebble Classic | 144x168 | Rect | B&W | 24 KB |
| diorite | Pebble 2 | 144x168 | Rect | B&W | 64 KB |
| flint | Pebble 2 Duo | 144x168 | Rect | 64-color | 64 KB |

- **Default and exclusive first target: emery.** Add gabbro only as a second pass unless the user asks for it.
- Alloy runs on **emery and gabbro only**.
- Emery/gabbro support touch; older platforms do not.
- Background worker limit: 10.5 KB.
- Use `PBL_IF_ROUND_ELSE`, `PBL_IF_COLOR_ELSE`, `PBL_PLATFORM_EMERY`, `ACTION_BAR_WIDTH`, and `STATUS_BAR_LAYER_HEIGHT` rather than hardcoding.
- Emery safe layout area: X 2–197, Y 2–225. Center is (100, 114).
- Gabbro safe layout area is circular; keep content inside the inscribed circle and test with a round screenshot.
