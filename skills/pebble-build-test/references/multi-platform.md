# Multi-platform testing

Only needed when `targetPlatforms` includes more than emery.

```bash
pebble build
pebble screenshot --no-open --all-platforms
```

- This builds/installs/screenshots every target platform in one run.
- Review each image: rect vs round, color vs B&W, action bar width, status bar height.
- `pebble screenshot --all-platforms` may use an existing PBW; run `pebble build` first for current code.
- GIF capture (`--gif-all-platforms`) records a rollover; use for animated/dynamic apps, skip for static faces.
- Delete screenshots/GIFs for platforms you did not target.
- Alloy projects can only include emery/gabbro.
