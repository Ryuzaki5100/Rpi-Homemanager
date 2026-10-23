---
name: pebble-build-test
description: Builds a Pebble project into a PBW, installs it in the QEMU emulator (emery by default), captures and visually verifies screenshots, drives buttons/taps, captures logs, tests AppMessage/Clay, runs multi-platform checks, and recovers a wedged emulator. Use after implementation and before delivery, or whenever a build, screenshot, emulator, or runtime failure needs diagnosis.
---

# pebble-build-test

Own the build → install → screenshot → visual QA → interaction/phone QA loop. Do not declare success until the screenshot and logs are verified.

## Step 0 — Read the test guide first (mandatory)
`read <base-dir>/GUIDE.md` before running the loop. Use `references/emulator.md` for commands and hygiene, `references/visual-qa.md` for the checklist, and `references/interaction.md` for watchapp/phone tests.

## Core rules (always apply)
1. **Build first**: `pebble build` must succeed and produce `build/*.pbw`.
2. **Install on emery**: `pebble install --emulator emery`.
3. **Screenshot with `--no-open`** and view it with the Read tool. An unviewed screenshot is not verification.
4. **Screenshot does not create directories**; `mkdir -p` first.
5. **Start log capture before install** when startup output matters; kill the streamer afterward.
6. **Stale emulator → `pebble kill && pebble wipe`**, then reinstall. Never debug code from a screenshot of another app.
7. **Launcher after install** may mean the app is not focused, not crashed. Press SELECT and check logs.
8. **Check all four visual categories**: cropping, positioning, color/contrast, design intent.
9. **Watchapps must be interacted with**: every screen, button path, and exit behavior.
10. **Phone features must be tested** with `emu-app-config` / `send-app-message` when present.
11. **Iterate until gates pass**; do not deliver with a crash, clipping, or untested interaction.
12. **Clean up**: kill log process and emulator when done.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Run the full build/test loop | `GUIDE.md` | Ordered commands and gates |
| Understand emulator commands/hygiene | `references/emulator.md` | install, buttons, taps, sensors, kill/wipe |
| Visually verify a screenshot | `references/visual-qa.md` | Pass/fail checklist |
| Test watchapp interactions | `references/interaction.md` | Buttons, menus, game loops |
| Read/interpret logs | `references/logs.md` | APP_LOG, crashes, memory |
| Test multiple platforms | `references/multi-platform.md` | `--all-platforms`, screenshots, GIFs |
| Capture logs in the background | `scripts/start-logs.sh` | Safe log streamer with PID file |
| Capture a screenshot | `scripts/capture-screenshot.sh` | mkdir + `--no-open` + path |

## Workflow
1. Read `GUIDE.md`.
2. `pebble build`; fix compiler errors.
3. Start logs (`scripts/start-logs.sh`), install on emery, wait for render.
4. `scripts/capture-screenshot.sh`; view the PNG.
5. Apply `references/visual-qa.md`; fix and repeat until pass.
6. Run interaction tests; repeat for failures.
7. Run phone tests if applicable.
8. Check logs for errors; stop the log streamer.
9. Report PBW, screenshot, gate results, and any limitation.

## Output
`build/<name>.pbw`, `screenshot_emery.png`, logs, and a verification report (`.pebble/verification.md`). No source edits unless fixing a verified failure.

## Tools
`read` (screenshots), `bash` (build/emulator), `write`/`edit` (fixes), `grep` (logs).
