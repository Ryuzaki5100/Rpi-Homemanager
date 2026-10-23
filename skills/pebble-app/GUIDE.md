# Pebble app orchestration guide

This guide owns the pipeline and the quality gates. Sub-skills own the domain detail.

## 1. Intake

Collect or infer:
- Name, display name, author.
- Watchface or watchapp.
- Target platform(s) — default `emery`.
- Language — C or Alloy.
- Visual/behavior description.
- Phone integration: none, AppMessage/web data, location, Clay settings.
- Publishing intent.

If the request is missing a visual description, ask one concise question. Do not ask about implementation details the suite can decide.

Write `.pebble/state.json` from `templates/state.json`.

## 2. Classification

Use this matrix and record the result:

| Signal | Choose |
|---|---|
| Passive time display, no buttons, no menus | Watchface |
| Buttons, menus, multiple screens, game input, countdown controls | Watchapp |
| Emery/gabbro only + modern JS/networking/UI iteration | Alloy |
| Older platform required, max performance, MenuLayer/ActionBar, Health/Glances/timeline/workers | C |
| Weather, HTTP, location, settings | Add `pebble-phone` (PKJS + Clay) |

Defaults: watchfaces and web-API apps → Alloy; games and menu-driven apps → C. If the user names a language or platform, honor it.

## 3. Phase gates

### G0 — Environment
`pebble --version`, `pebble sdk list` shows the Nix SDK active, `qemu-pebble --version`, `pebble-python -c 'import PIL'`.
Fail → `pebble-sdk-setup`. Never run `pebble sdk install` in the Nix setup.

### G1 — Metadata
`package.json` has a valid UUID, correct `watchapp.watchface`, valid `targetPlatforms`, all message keys, and the right `projectType`. Run `pebble-core/scripts/validate_project.py`.

### G2 — Design
`.pebble/design.md` exists and computes every element's bottom/right edge. No element may exceed the screen; Quick View and round behavior are addressed when relevant.

### G3 — Build
`pebble build` succeeds and `build/*.pbw` exists.

### G4 — Visual QA
Install on emery, capture a screenshot, **view it with the Read tool**, and pass the cropping/position/color/intent checklist from `pebble-build-test`.

### G5 — Interaction QA
Watchapps: every button path, menu selection, game loop start/stop, and exit behavior tested with `pebble emu-button` / `pebble emu-tap`.

### G6 — Phone QA
If PKJS/Clay is present: AppMessage round trip, `pebble emu-app-config`, settings persist, no uncaught JS errors in `pebble logs`.

### G7 — Assets
Icons and preview GIF exist for animated/dynamic apps; multi-platform screenshots exist only if the user targets multiple platforms.

### G8 — Delivery
Report the PBW, verified screenshot(s), GIF, install commands, and known limitations. Offer publishing; do not publish without consent.

## 4. Failure loops

- Build failure → read the compiler error, fix the source, rebuild. Do not change metadata to hide the error.
- Wrong screenshot / stale app → `pebble kill && pebble wipe`, reinstall.
- Launcher shown after install → `pebble emu-button click select`.
- Crash → capture logs before relaunching; fix; retest.
- Cropping → use `bounds.size` and recompute edges; do not shrink fonts until content fits by design.
- Phone failure → check `messageKeys` in `package.json`, watch, PKJS, and Clay; verify callbacks are registered before `app_message_open`.
- Alloy white screen → check system font name/size first, then module registration.

## 5. Sub-skill hand-offs

Always pass:
- project root path,
- project type and language,
- target platforms,
- path to `.pebble/design.md` (after design),
- whether phone integration is required,
- the exact artifact expected from the phase.

Read `references/routing.md` for the invocation prompt for each skill. Read `references/contracts.md` for artifact requirements.

## 6. Delivery report

Use `templates/final-report.md`. Include:
- PBW absolute path.
- Verified screenshot(s) and preview GIF.
- What the app shows/does.
- Install commands for emulator and device.
- Any platform limitation or unverified area.
- Next optional step: gabbro support or publish.
