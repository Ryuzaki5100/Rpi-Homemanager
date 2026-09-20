# Omarchy Plugin Reference Samples

Read-only reference implementations for the `omarchy-plugin-creator` skill.
Copy from these, do not edit them in place. They exist so a generated plugin
matches the real Quickshell/Omarchy contract instead of a guess.

Every sample here is modeled on a working first-party plugin:

| Sample | Modeled on | Demonstrates |
|---|---|---|
| `bar-widget-with-panel/` | `omarchy.clock` | The standard bar-widget-with-nested-panel pattern: `BarWidget` + `WidgetButton` + `Loader` + `injectPanel()`, and a `Panel` with `KeyboardPanel`/`PanelKeyCatcher`. |
| `standalone-panel/` | `omarchy.wifiqr` | A standalone `panel` kind: an `Item` with a `PanelWindow` layer surface, `open(payloadJson)`/`close()`/`dismiss()`. |
| `service/` | `omarchy.battery` / `omarchy.system-update` | A headless `service` kind: `Process` + `Timer`, no UI. |
| `helper-script-bar-widget/` | `stochi` | Thin QML plus an executable helper script resolved with `Qt.resolvedUrl(...)`. |

## Rules these samples encode

- A bar widget with a drop-down keeps **one** `bar-widget` kind. The entry
  point `BarWidget.qml` loads `Panel.qml` internally; do not declare a second
  `panel` kind for a nested panel.
- Both files share the same `moduleName`.
- The bar widget forwards `opened`, `open()`, `close()`, `toggle()`, and
  `closeForPopoutSwitch()` to the loaded panel.
- `PanelKeyCatcher` closes via `onCloseRequested` (not `onEscape`) and switches
  panels via `onTabRequested`.
- Buttons are `WidgetButton` with `onPressed: function(button) { ... }`.
- Theme only through `qs.Commons` (`Color`, `Style`, `Border`, `Util`).
- `moduleName` and every id are namespaced; never `omarchy.*`.

## Validate a copy

```sh
omarchy plugin validate ./my-plugin
qmllint -I "$OMARCHY_PATH/shell" ./my-plugin/*.qml
```
