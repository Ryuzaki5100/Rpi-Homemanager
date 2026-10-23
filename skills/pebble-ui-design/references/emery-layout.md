# Emery layout reference

- Screen: 200x228
- Safe: X 2..197, Y 2..225
- Center: (100, 114)
- Status bar height: 16
- Action bar width (emery/gabbro): 34

## Common bands

| Band | Y range | Notes |
|---|---|---|
| Status | 0–16 | Battery/BT icons or StatusBarLayer |
| Hero time | 28–100 | Largest text; leave breathing room |
| Date | 104–128 | 14–18 px font |
| Secondary data | 132–160 | Weather, steps, battery % |
| Footer/art | 164–222 | Keep 3–5 px bottom margin |

## Useful formulas

```c
int cx = bounds.size.w / 2;
int cy = bounds.size.h / 2;
int x = (bounds.size.w - w) / 2;
int y = bounds.size.h - h - 4;
```

## Cropping checklist

- Bottom edge `y + h <= bounds.size.h - 2`
- Right edge `x + w <= bounds.size.w - 2`
- GPath negative offsets remain inside the anchor-relative shape
- Text layers are tall enough for the font's line height
