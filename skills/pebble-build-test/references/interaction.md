# Interaction testing

## Watchface

- Tap: `pebble emu-tap --emulator emery`.
- No button behavior should be expected.
- Confirm the face redraws on minute change (use `emu-set-time` if needed).

## Watchapp

For every screen:
- `select` opens/acts,
- `up`/`down` scroll or move,
- `back` pops,
- long `select`/`back` if implemented,
- repeat/hold if implemented.

```bash
pebble emu-button click select --emulator emery
pebble emu-button click up --emulator emery
pebble emu-button click down --emulator emery
pebble emu-button click back --emulator emery
pebble emu-button click select --duration 2000 --emulator emery
```

## Game loop

- Start the game; confirm motion/animation.
- Hold a direction; confirm continuous movement.
- Exit; confirm the timer stops (no continued logs/CPU).
- Re-enter; confirm state/score handling.

## Menus

- Scroll to every row.
- Select each row; open its detail.
- BACK from each detail.
- Confirm no duplicate click subscriptions.

## Failure signs

- Unresponsive buttons → click config not installed on the visible window.
- Immediate exit → crash; check logs.
- Stuck screen → timer not scheduled or layer not marked dirty.
- Double actions → multiple click subscriptions.
