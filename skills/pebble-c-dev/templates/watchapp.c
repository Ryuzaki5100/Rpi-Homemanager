#include <pebble.h>

static Window *s_main_window;
static TextLayer *s_title_layer;
static int s_count;

static void update_title(void) {
  static char buf[32];
  snprintf(buf, sizeof(buf), "Count: %d", s_count);
  text_layer_set_text(s_title_layer, buf);
}

static void select_click_handler(ClickRecognizerRef recognizer, void *context) {
  s_count++;
  update_title();
}

static void click_config_provider(void *context) {
  window_single_click_subscribe(BUTTON_ID_SELECT, select_click_handler);
}

static void main_window_load(Window *window) {
  Layer *root = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(root);

  s_title_layer = text_layer_create(GRect(0, bounds.size.h / 2 - 20, bounds.size.w, 40));
  text_layer_set_text_alignment(s_title_layer, GTextAlignmentCenter);
  text_layer_set_font(s_title_layer, fonts_get_system_font(FONT_KEY_GOTHIC_24_BOLD));
  layer_add_child(root, text_layer_get_layer(s_title_layer));
  update_title();
}

static void main_window_unload(Window *window) {
  text_layer_destroy(s_title_layer);
}

static void init(void) {
  s_main_window = window_create();
  window_set_click_config_provider(s_main_window, click_config_provider);
  window_set_window_handlers(s_main_window, (WindowHandlers) {
    .load = main_window_load,
    .unload = main_window_unload,
  });
  window_stack_push(s_main_window, true);
}

static void deinit(void) {
  window_destroy(s_main_window);
}

int main(void) {
  init();
  app_event_loop();
  deinit();
  return 0;
}
