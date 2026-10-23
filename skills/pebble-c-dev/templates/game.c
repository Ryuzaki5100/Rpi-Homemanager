#include <pebble.h>

#define FRAME_MS 33

static Window *s_window;
static Layer *s_game_layer;
static AppTimer *s_timer;
static int s_x = 100, s_y = 114;
static bool s_left, s_right, s_up, s_down;

static void update_state(void) {
  if (s_left) s_x -= 4;
  if (s_right) s_x += 4;
  if (s_up) s_y -= 4;
  if (s_down) s_y += 4;
  GRect b = layer_get_bounds(window_get_root_layer(s_window));
  if (s_x < 8) s_x = 8;
  if (s_x > b.size.w - 8) s_x = b.size.w - 8;
  if (s_y < 8) s_y = 8;
  if (s_y > b.size.h - 8) s_y = b.size.h - 8;
}

static void tick(void *data) {
  update_state();
  layer_mark_dirty(s_game_layer);
  s_timer = app_timer_register(FRAME_MS, tick, NULL);
}

static void game_draw(Layer *layer, GContext *ctx) {
  GRect b = layer_get_bounds(layer);
  graphics_context_set_fill_color(ctx, GColorBlack);
  graphics_fill_rect(ctx, b, 0, GCornerNone);
  graphics_context_set_fill_color(ctx, GColorWhite);
  graphics_fill_circle(ctx, GPoint(s_x, s_y), 8);
}

static void up_down(ClickRecognizerRef r, void *ctx) { s_up = true; }
static void up_up(ClickRecognizerRef r, void *ctx) { s_up = false; }
static void down_down(ClickRecognizerRef r, void *ctx) { s_down = true; }
static void down_up(ClickRecognizerRef r, void *ctx) { s_down = false; }
static void sel_down(ClickRecognizerRef r, void *ctx) { s_right = true; }
static void sel_up(ClickRecognizerRef r, void *ctx) { s_right = false; }
static void back_down(ClickRecognizerRef r, void *ctx) { s_left = true; }
static void back_up(ClickRecognizerRef r, void *ctx) { s_left = false; }

static void click_config_provider(void *context) {
  window_raw_click_subscribe(BUTTON_ID_UP, up_down, up_up, NULL);
  window_raw_click_subscribe(BUTTON_ID_DOWN, down_down, down_up, NULL);
  window_raw_click_subscribe(BUTTON_ID_SELECT, sel_down, sel_up, NULL);
  window_raw_click_subscribe(BUTTON_ID_BACK, back_down, back_up, NULL);
}

static void window_load(Window *window) {
  Layer *root = window_get_root_layer(window);
  s_game_layer = layer_create(layer_get_bounds(root));
  layer_set_update_proc(s_game_layer, game_draw);
  layer_add_child(root, s_game_layer);
}

static void window_appear(Window *window) {
  if (!s_timer) s_timer = app_timer_register(FRAME_MS, tick, NULL);
}

static void window_disappear(Window *window) {
  if (s_timer) { app_timer_cancel(s_timer); s_timer = NULL; }
}

static void window_unload(Window *window) {
  layer_destroy(s_game_layer);
}

static void init(void) {
  s_window = window_create();
  window_set_click_config_provider(s_window, click_config_provider);
  window_set_window_handlers(s_window, (WindowHandlers) {
    .load = window_load,
    .appear = window_appear,
    .disappear = window_disappear,
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
