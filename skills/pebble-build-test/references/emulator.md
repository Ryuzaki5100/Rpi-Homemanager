# Emulator reference

## Core commands

```bash
pebble install --emulator emery
pebble screenshot --no-open --emulator emery shot.png
pebble logs --emulator emery
pebble emu-button click select --emulator emery
pebble emu-button click back --duration 2000 --emulator emery
pebble emu-tap --emulator emery
pebble emu-battery --percent 30 --emulator emery
pebble emu-bt-connection --connected no --emulator emery
pebble emu-set-timeline-quick-view on --emulator emery
pebble emu-app-config   # opens a browser; may block in headless sessions
pebble send-app-message --int 1=42 --string 2=hello
pebble kill
pebble wipe
```

## Hygiene

- First emulator boot is slow; wait ~20 s before install.
- The first install can print `Connection refused` while pypkjs/websockify start. Retry `pebble install` once; it reuses the running emulator.
- Install can land on the launcher with the app highlighted; press SELECT.
- A crashed app also lands on the launcher; relaunch and read logs to distinguish.
- `libpebble2.exceptions.TimeoutError` → `pebble kill && pebble wipe`, reinstall.
- `pebble screenshot` does not create directories.
- Use `--vnc` on every emulator command in headless environments.

## Keyboard mapping (when using the GUI)

Back: Q/left, Up: W/up, Select: S/right, Down: X/down.
