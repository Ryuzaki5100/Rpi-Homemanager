# Visual QA checklist

View the screenshot with the Read tool, then grade each category.

## A. Cropping
- [ ] Every visual element is fully visible.
- [ ] No clipping at the left/right/top/bottom edges.
- [ ] Text is not truncated.
- [ ] Bottom elements have at least 2–5 px margin.
- [ ] GPath shapes do not extend outside the screen.

## B. Positioning
- [ ] Time/hero element is where the design says.
- [ ] Elements match the design table's x/y.
- [ ] Centered elements are actually centered.
- [ ] Spacing is balanced and intentional.

## C. Color and contrast
- [ ] Primary text is readable.
- [ ] Secondary text is readable.
- [ ] Color theme matches the request.
- [ ] B&W/round platform variants remain readable.

## D. Design intent
- [ ] The theme is recognizable.
- [ ] The requested features are visible.
- [ ] The composition looks intentional, not accidental.
- [ ] Animation frame (if captured) shows the intended state.

## Verdict

If any item fails, **do not deliver**. Fix the layout/code, rebuild, reinstall, capture a new screenshot, and re-grade.

## Common fixes
- Bottom crop: `y = bounds.size.h - h - margin`.
- Side crop: `x = (bounds.size.w - w) / 2` or right-anchor with margin.
- Text clip: measure with `graphics_text_layout_get_content_size` / `getTextWidth`, resize or reduce content.
- Wrong colors: use `PBL_IF_COLOR_ELSE` and explicit `GColor*` values.
