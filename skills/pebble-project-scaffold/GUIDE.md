# Project scaffolding guide

## 1. Inputs

- `name`: lowercase slug used for the directory and `package.json.name`.
- `displayName`: shown on the watch and in the app store.
- `author`.
- `type`: `watchface` or `watchapp`.
- `language`: `C` or `Alloy`.
- `platforms`: default `["emery"]`.
- `phone`: `none`, `pkjs`, or `clay`.

## 2. Create

```bash
python3 scripts/scaffold.py my-face --face --c --platforms emery
python3 scripts/scaffold.py my-app --app --c --platforms emery --phone clay
python3 scripts/scaffold.py my-alloy-face --face --alloy --platforms emery
```

The script refuses to overwrite an existing directory. Use `--output DIR` to choose the parent.

## 3. Metadata review

- UUID is unique.
- `watchapp.watchface` matches the type.
- `targetPlatforms` is non-empty; Alloy is a subset of emery/gabbro.
- `resources.media` lists fonts/images.
- `messageKeys` contains every key in the C/JS/Clay code.
- `capabilities` contains `location` and/or `configurable` only when used.

## 4. Validate

```bash
python3 ../pebble-core/scripts/validate_project.py .
```

Expected: all checks pass, or only intentional warnings. Fix errors before handing off.

## 5. Hand-off

- Design: `pebble-ui-design` writes `.pebble/design.md`.
- C: `pebble-c-dev` fills `src/c/main.c`.
- Alloy: `pebble-alloy-dev` fills `src/embeddedjs/main.js`.
- Phone: `pebble-phone` fills `src/pkjs/`.
- Build/test: `pebble-build-test`.
