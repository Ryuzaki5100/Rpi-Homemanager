# App-only services

## Persistent storage

```c
persist_write_int(KEY_SCORE, score);
int score = persist_read_int(KEY_SCORE);
persist_exists(KEY);
persist_delete(KEY);
```

256 B per value, ~4 KB total. Save on disappear.

## Wakeups

```c
WakeupId id = wakeup_schedule(timestamp, cookie, true);
wakeup_service_subscribe(wakeup_handler);
if (launch_reason() == APP_LAUNCH_WAKEUP) wakeup_get_launch_event(&id, &cookie);
```

Max 8 scheduled; no two within 1 minute. Store IDs in persist.

## App Glances

```c
app_glance_reload(glance_reload_cb, NULL);
app_glance_add_slice(session, (AppGlanceSlice){
  .layout = {.icon = ..., .subtitle_template_string = "..."},
  .expiration_time = APP_GLANCE_SLICE_NO_EXPIRATION
});
```

Not available on aplite.

## Background worker

- `worker_src/c/worker.c` with `#include <pebble_worker.h>`, `main()`, `worker_event_loop()`.
- 10.5 KB limit; no UI/AppMessage/resources.
- `app_worker_launch()` / `app_worker_kill()`.
- Shared persist storage; AppWorkerMessage for live communication.

## Status bar / action bar

- `status_bar_layer_create()` and reserve `STATUS_BAR_LAYER_HEIGHT`.
- `action_bar_layer_create()` and reserve `ACTION_BAR_WIDTH` (34 on emery/gabbro).
