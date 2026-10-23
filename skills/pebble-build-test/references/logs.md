# Logs and debugging

## Safe capture

```bash
PYTHONUNBUFFERED=1 pebble logs --emulator emery > pebble-logs.txt 2>&1 &
echo $! > .pebble-logs.pid
```

Start before install to capture startup output. Kill with `kill $(cat .pebble-logs.pid)`.

## Common entries

- `APP_LOG(APP_LOG_LEVEL_ERROR, ...)` — app error.
- `Heap Usage for App` — normal exit/memory report; not necessarily a crash.
- `App fault!` / backtrace — crash; reproduce and inspect the last log lines.
- `TypeError` in Alloy — JS exception; check fonts/modules first.
- `APP_MSG_*` — AppMessage failures.

## C debugging

- `pebble build --debug`, then `pebble gdb`.
- `pebble analyze-size` for memory pressure.
- Check `heap_bytes_free()` in logs.

## Alloy debugging

- `pebble logs` for `console.log`.
- `xsbug` for breakpoints (`pebble build --debug`).
- White screen at launch: check font name/size and manifest module registration.
