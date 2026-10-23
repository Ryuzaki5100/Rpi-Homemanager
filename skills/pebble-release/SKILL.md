---
name: pebble-release
description: Generates Pebble release assets (80x80 and 144x144 icons, preview GIFs, multi-platform screenshots), prepares store listing metadata, and publishes a PBW to the Pebble app store with pebble publish. Use after visual/interaction tests pass, or when the user asks for icons, a preview GIF, a store listing, or publishing.
---

# pebble-release

Turn a verified PBW into a shippable listing. Assets and publishing only; do not skip the build/test gates.

## Step 0 — Read the release guide first (mandatory)
`read <base-dir>/GUIDE.md` before generating assets or publishing. Use `references/assets.md`, `references/publishing.md`, and `references/store-listing.md`.

## Core rules (always apply)
1. **Only release after `pebble-build-test` passes** (build, visual QA, interaction/phone QA).
2. **Use the verified screenshot** as the icon/GIF source; do not use a stale or wrong-app image.
3. **Icons**: `icon_80x80.png` and `icon_144x144.png` in the project root.
4. **Preview GIFs are for animated/dynamic apps**; a static MINUTE_UNIT face produces a 1-frame GIF — skip it.
5. **Preview capture sees every running emulator**; kill non-target emulators or delete non-target GIFs.
6. **Publish only with explicit user consent.**
7. **`pebble publish` requires `pebble login`**; check status first.
8. **Never invent store copy**; base descriptions on verified behavior.
9. **No secrets or private data in screenshots, lists, or release notes.**

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Generate icons/GIFs/screenshots | `references/assets.md` | Commands, sizes, caveats |
| Publish or prepare CI | `references/publishing.md` | `pebble login`, `pebble publish`, flags |
| Write the listing | `references/store-listing.md` | Title/description/category/release notes |
| Start a listing document | `templates/store-listing.md` | Store copy skeleton |
| Generate icons | `scripts/create_app_icons.py` | Screenshot → 80/144 icons |
| Generate a preview GIF | `scripts/create_preview_gif.py` | Multi-frame emulator capture |

## Workflow
1. Read `GUIDE.md`; confirm the test report passes.
2. Ensure only the target emulator is running.
3. Generate icons and (if animated) the preview GIF.
4. Write the store listing from verified behavior.
5. If publishing: `pebble login --status`, then `pebble publish` (interactive) or the non-interactive flags.
6. Report asset paths, listing text, and publish result.

## Output
`icon_80x80.png`, `icon_144x144.png`, optional `preview_emery.gif`, `screenshot_emery.png`, a store listing, and optionally an uploaded release.

## Tools
`read`, `write`/`edit`, `bash` (scripts, `pebble login/publish`), `question` (publish consent/category).
