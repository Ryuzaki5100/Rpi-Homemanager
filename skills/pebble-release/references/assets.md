# Icons, GIFs, and screenshots

## Screenshots

```bash
pebble screenshot --no-open --emulator emery screenshot_emery.png
pebble screenshot --no-open --all-platforms
```

- Screenshot does not create directories.
- Run `pebble build` first; `--all-platforms` may use an existing PBW.
- Review each screenshot before uploading.

## Icons

```bash
pebble-python scripts/create_app_icons.py .
```

Outputs:
- `icon_80x80.png`
- `icon_144x144.png`

## Preview GIF

```bash
pebble-python scripts/create_preview_gif.py . --frames 8 --delay 400
```

- Captures every running emulator; isolate the target first.
- Static faces: skip.
- Games: start gameplay first.
- Multi-platform: `pebble screenshot --gif-all-platforms` is the built-in alternative.

## Store image sizes

Check https://developer.repebble.com/guides/appstore-publishing/preparing-a-submission.md for the current required sizes; the app store rules can change.
