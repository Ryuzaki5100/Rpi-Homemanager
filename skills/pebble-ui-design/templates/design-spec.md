# Design spec: <name>

- **Type:** <watchface|watchapp>
- **Language:** <C|Alloy>
- **Platforms:** <emery|gabbro|...>
- **Screen:** <WxH, shape, colors>

## Layout

| Element | x | y | w | h | right edge | bottom edge | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Background | 0 | 0 | W | H | W | H | full screen |
| Time |  |  |  |  |  |  | hero |
| Date |  |  |  |  |  |  |  |
| Data |  |  |  |  |  |  |  |

Safe limits: right < W - 2, bottom < H - 2.

## Typography

| Element | Font | Size | Color | Alignment |
|---|---|---|---|---|
| Time |  |  |  | center |

## Palette

| Role | Color | Hex/name |
|---|---|---|
| Background |  |  |
| Primary |  |  |
| Secondary |  |  |
| Accent |  |  |

## Behavior

- Update timing:
- Animation:
- Tap/accelerometer:
- Quick View handling:
- Round handling:

## Interaction map (watchapps)

| Screen | Select | Up | Down | Back |
|---|---|---|---|---|
|  |  |  |  |  |

## Risks

- Longest strings:
- Edge cases:
