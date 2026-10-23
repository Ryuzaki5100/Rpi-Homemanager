# Watchapp UX

## Buttons

- **Back**: pop window; long-press exits (cannot be overridden).
- **Up/Down**: scroll/navigate or game movement.
- **Select**: open/confirm/action.
- Use `window_single_click_subscribe`, `window_long_click_subscribe`, `window_single_repeating_click_subscribe`, `window_multi_click_subscribe`, and `window_raw_click_subscribe` as needed.
- MenuLayer/SimpleMenuLayer/ActionBarLayer/ScrollLayer install their own click config; do not double-subscribe.

## Window stack

- One Window per screen.
- Push on select; BACK pops automatically.
- Use `.appear` (not only `.load`) to refresh a reused detail window.
- App exits when the stack empties.
- `exit_reason_set(APP_EXIT_ACTION_PERFORMED_SUCCESSFULLY)` for one-shot actions.

## Games

- Raw click down/up sets/clears held-button flags.
- 33 ms `AppTimer` loop calls `layer_mark_dirty`.
- Cancel the timer in `disappear`/`unload`.
- Persist high score/state in `persist_*` on disappear.

## Design checklist

- [ ] Every screen has a way back.
- [ ] The first screen is usable within one click.
- [ ] Held-button behavior is intentional.
- [ ] Long-press BACK is not assigned (system-reserved).
- [ ] No timer runs while the app is hidden.
