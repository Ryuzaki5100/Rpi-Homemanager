# Release guide

## 1. Preconditions

- `build/<name>.pbw` exists and was tested.
- `.pebble/verification.md` says visual/interaction/phone gates pass.
- The emulator is showing the correct app.

## 2. Icons

```bash
pebble-python scripts/create_app_icons.py .
```

Produces `icon_80x80.png` and `icon_144x144.png` from the current screenshot.

## 3. Preview GIF

For animated/dynamic apps/games only:

```bash
pebble-python scripts/create_preview_gif.py . --frames 8 --delay 400
```

- Kill emulators for non-target platforms first.
- A static MINUTE_UNIT face gets a 1-frame GIF; skip it.
- For games, start gameplay before capture so frames show play, not the menu.
- Delete GIFs for platforms you do not target.

## 4. Store listing

Use `templates/store-listing.md`. Keep the description factual and keyword-aware:
- what it shows/does,
- target platforms,
- settings/phone requirements,
- any limitations.

## 5. Publish

```bash
pebble login
pebble login --status
pebble publish
```

Interactive publish builds, captures assets, prompts for listing details, and uploads.

Non-interactive:

```bash
pebble publish --non-interactive \
  --name "My App" \
  --description "..." \
  --category daily \
  --release-notes "Initial release"
```

Check current flags with `pebble publish --help`; the tool has changed over time.

## 6. Verify

- Listing shows the correct title/description/screenshots.
- Release notes are accurate.
- The uploaded PBW matches the verified build.
- Do not mark a release public unless the user asked.
