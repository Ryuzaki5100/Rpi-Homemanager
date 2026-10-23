# C watchface patterns

## Time and date

```c
static void tick_handler(struct tm *tick_time, TimeUnits units_changed) {
  static char time_buf[8];
  static char date_buf[24];
  strftime(time_buf, sizeof(time_buf), clock_is_24h_style() ? "%H:%M" : "%I:%M", tick_time);
  strftime(date_buf, sizeof(date_buf), "%a %b %d", tick_time);
  text_layer_set_text(s_time_layer, time_buf);
  text_layer_set_text(s_date_layer, date_buf);
}

tick_timer_service_subscribe(MINUTE_UNIT, tick_handler);
```

- `MINUTE_UNIT` always, unless the user explicitly wants seconds.
- `clock_is_24h_style()` for locale-correct formatting.
- Force an initial update by reading the current time in `window_load` or calling the handler with a local `time_t`.

## Battery / Bluetooth

```c
static void battery_callback(BatteryChargeState state) {
  static char buf[8];
  snprintf(buf, sizeof(buf), "%d%%", state.charge_percent);
  text_layer_set_text(s_battery_layer, buf);
}
battery_state_service_subscribe(battery_callback);
battery_callback(battery_state_service_peek());
```

Unsubscribe in `deinit`.

## Analog hands

- Pre-create `GPath` for hour/minute/second hands in `window_load`.
- Rotate with `gpath_rotate_to(path, DEG_TO_TRIGANGLE(degrees))`.
- Draw with `gpath_draw_filled(ctx, path)`.
- Anchor the path at the hand's pivot; points extend out from (0,0).

## Weather display

- C receives AppMessage values from PKJS; do not call HTTP from C.
- Store weather code/condition in static state; redraw on inbox received.
- Branch visuals on the code, not on a long string, when possible.

## Battery-friendly variety

Use a minute counter to offset deterministic elements:

```c
static int s_frame;
// in tick_handler: s_frame++;
int rx = (i * 37 + s_frame * 7) % bounds.size.w;
```

This changes the scene each minute without a sub-second timer.
