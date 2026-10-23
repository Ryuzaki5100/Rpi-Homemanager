# Typography and color

## C system fonts
- Fetch https://developer.repebble.com/guides/app-resources/system-fonts.md before choosing a font.
- Names look like `FONT_KEY_BITHAM_42_BOLD`, `FONT_KEY_GOTHIC_24_BOLD`, `FONT_KEY_ROBOTO_CONDENSED_21`.
- Use `graphics_text_layout_get_content_size()` to measure text and avoid clipping.

## Alloy system fonts
Valid name+size combinations (from the Alloy guide):

| Family | Sizes |
|---|---|
| Gothic-Regular / Gothic-Bold | 14, 18, 24, 28 |
| Bitham-Bold | 42 |
| Bitham-Black | 30 |
| Bitham-Light | 42 |
| Roboto-Condensed | 21 |
| Leco-Regular | 20, 26, 28, 32, 36, 38, 42 |
| Droid-Serif | 28 |

An invalid combination can crash the JS VM at launch with a white screen.

## Palette
- Choose 3–5 colors: background, primary, secondary, accent, shadow.
- Check contrast on the actual emulator, not just in a color picker.
- B&W platforms (aplite/diorite) must remain readable without color.
- Use `PBL_IF_COLOR_ELSE` for platform-specific choices.

## Text fitting
- Longest realistic strings: `Wed, Sep 30`, `-18°`, `100%`, `T-Storm`.
- Leave 2–4 px padding inside text layers.
- If text clips, reduce content or change the layout; do not hide overflow with a smaller margin.
