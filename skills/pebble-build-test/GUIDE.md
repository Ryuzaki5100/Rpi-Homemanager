# Build and test guide

## 1. Build

```bash
cd <project>
pebble build
ls -la build/*.pbw
```

If it fails, fix the first compiler error and rebuild. Do not proceed with a stale PBW.

## 2. Install and capture logs

```bash
scripts/start-logs.sh emery
pebble install --emulator emery
```

Wait a few seconds for the app to render. If the emulator is booting for the first time, wait ~20 s before installing. If the first install reports `Connection refused`, rerun `pebble install --emulator emery`; the emulator/pypkjs processes are already starting.

## 3. Screenshot

```bash
scripts/capture-screenshot.sh emery screenshot_emery.png
```

Then **view `screenshot_emery.png` with the Read tool**.

## 4. Visual QA

Use `references/visual-qa.md`. Fail categories:
- anything clipped at any edge,
- text truncated,
- layout not matching `.pebble/design.md`,
- unreadable contrast,
- theme/features not recognizable.

Fix, rebuild, reinstall, screenshot, re-view. Repeat.

## 5. Interaction QA

```bash
pebble emu-button click select --emulator emery
pebble emu-button click up --emulator emery
pebble emu-button click down --emulator emery
pebble emu-button click back --emulator emery
pebble emu-button click select --duration 2000 --emulator emery
pebble emu-tap --emulator emery
```

For each watchapp:
- open every screen,
- trigger every select/up/down path,
- test long/repeat where implemented,
- confirm BACK returns correctly,
- confirm the app exits cleanly when the stack empties,
- for games, confirm the loop starts and stops (no CPU burn after exit).

## 6. Phone QA

```bash
pebble emu-app-config
pebble send-app-message --int 1=42 --string 2=hello
```

Confirm:
- Clay page opens; save updates the watch,
- AppMessage inbox handler updates the UI,
- PKJS logs show no uncaught errors,
- missing location/network is handled.

## 7. Logs

```bash
scripts/start-logs.sh emery   # if not already running
tail -n 100 pebble-logs.txt
kill $(cat .pebble-logs.pid)
```

Look for `APP_LOG` errors, crashes, and memory warnings. An empty log is normal for an app that does not log.

## 8. Multi-platform

Only if `targetPlatforms` has more than emery:

```bash
pebble build
pebble screenshot --no-open --all-platforms
```

Review each platform screenshot; round/rect and color/B&W differences matter.

## 9. Recovery

```bash
pebble kill
pebble wipe
pebble install --emulator emery
```

Use this for stale screenshots, wedged installs, timeouts, or a launcher that keeps reappearing.

## 10. Report

Fill `.pebble/verification.md`:
- build pass/fail,
- PBW path,
- visual checklist pass/fail,
- interaction results,
- phone results or n/a,
- log errors or none,
- final gate status.
