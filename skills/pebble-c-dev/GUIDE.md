# C implementation guide

## 1. Mode

| | Watchface | Watchapp |
|---|---|---|
| `watchapp.watchface` | `true` | `false` |
| Update | Tick timer | Clicks + timers |
| Buttons | None | Full click API |
| Exit | System | BACK pops the window stack |

## 2. Required skeleton

```c
#include <pebble.h>

static Window *s_window;

static void window_load(Window *window) { /* create layers, paths, fonts */ }
static void window_unload(Window *window) { /* destroy everything */ }

static void init(void) {
  s_window = window_create();
  window_set_window_handlers(s_window, (WindowHandlers) {
    .load = window_load,
    .unload = window_unload,
  });
  window_stack_push(s_window, true);
}

static void deinit(void) {
  window_destroy(s_window);
}

int main(void) {
  init();
  app_event_loop();
  deinit();
  return 0;
}
```

## 3. Watchface specifics

- `tick_timer_service_subscribe(MINUTE_UNIT, tick_handler)`.
- Read `tick_time->tm_hour`, `tm_min`, `tm_mday`, `tm_mon`, `tm_wday`.
- Use `strftime`/`snprintf` into static buffers.
- Battery/BT via `BatteryStateService`/`ConnectionService`; unsubscribe in deinit.
- Pre-allocate GPath for clock hands/static art.
- Brief animation only on tap or minute change; stop the timer.

## 4. Watchapp specifics

- `window_set_click_config_provider(window, click_config_provider)`.
- One Window per screen; push/pop on the stack.
- MenuLayer/SimpleMenuLayer/ActionBar/ScrollLayer install their own click config.
- Persist state in `window_disappear` with `persist_write_*`.
- Use `.appear` for reused detail windows.
- Games: raw click down/up flags + 33 ms timer; cancel on disappear.

## 5. Memory and resources

- Emery/gabbro: 128 KB; older platforms: 24–64 KB.
- Destroy GPath, GBitmap, fonts, TextLayer, MenuLayer, timers, and service subscriptions.
- Avoid `malloc` in draw; use static/stack structs.
- Use `heap_bytes_free()` when debugging.

## 6. AppMessage

Only when phone integration exists:

```c
app_message_register_inbox_received(inbox_received_callback);
app_message_register_inbox_dropped(inbox_dropped_callback);
app_message_open(app_message_inbox_size_maximum(), app_message_outbox_size_maximum());
```

Use `MESSAGE_KEY_*` constants generated from `package.json`.

## 7. Build feedback

```bash
pebble build
```

Read the first compiler error, fix it, rebuild. Do not proceed to emulator testing until the build is clean.
