# C game patterns

## Loop

```c
#define FRAME_MS 33
static AppTimer *s_timer;

static void tick(void *data) {
  update_state();
  layer_mark_dirty(s_game_layer);
  s_timer = app_timer_register(FRAME_MS, tick, NULL);
}

static void window_appear(Window *w) {
  if (!s_timer) s_timer = app_timer_register(FRAME_MS, tick, NULL);
}
static void window_disappear(Window *w) {
  if (s_timer) { app_timer_cancel(s_timer); s_timer = NULL; }
}
```

## Input

- Raw click down/up sets/clears held flags.
- Use `window_raw_click_subscribe(BUTTON_ID_UP, down, up, NULL)`.
- Do not use `window_single_click_subscribe` for held movement.
- BACK long-press exits; do not try to override it.

## State

- Keep a single game state struct.
- Update physics in `tick`, draw in the layer update proc.
- Use fixed-point integers; no floats.
- Clamp positions to bounds and handle collisions with simple AABB math.

## Persistence

```c
persist_write_int(KEY_HIGH_SCORE, score);
int high = persist_read_int(KEY_HIGH_SCORE);
```

Save on window disappear/unload. 256 B per value, ~4 KB total.

## Pause/resume

- Cancel the timer on disappear, restart on appear.
- If the game has an explicit pause screen, keep the timer stopped while paused.
