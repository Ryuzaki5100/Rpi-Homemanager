---
name: omarchy-plugin-creator
description: Use when the user wants to create, scaffold, or generate a new Omarchy shell plugin (bar widget, panel, overlay, menu, service, or full bar), or asks how to build, test, or locally develop one. Interviews the user for identity, purpose, bar appearance, expanded/panel appearance, settings, and helper-script language, then generates a complete valid plugin repo — manifest.json, QML extending the qs.Ui base classes, an optional helper script, Makefile, CI, README, and LICENSE — that passes `omarchy plugin validate` and `qmllint`. Also use for Omarchy plugin architecture, manifest, theming, or troubleshooting questions.
---

# Skill: omarchy-plugin-creator

Generate a complete, valid, theme-native Omarchy shell plugin by interviewing
the user first, then scaffolding the repo. Never invent APIs; verify against
`$OMARCHY_PATH/shell/`.

## Reference samples (read these first)

Working, contract-accurate samples ship alongside this file in `reference/`.
On a source checkout: `~/dotfiles/skills/omarchy-plugin-creator/reference/`.
Deployed: `~/.config/opencode/skills/omarchy-plugin-creator/reference/`.

| Sample | Modeled on | Use it for |
|---|---|---|
| `reference/bar-widget-with-panel/` | `omarchy.clock` | The standard bar-widget + nested-panel pattern |
| `reference/standalone-panel/` | `omarchy.wifiqr` | A standalone `panel` kind with a `PanelWindow` |
| `reference/service/` | `omarchy.battery` | A headless `service` kind |
| `reference/helper-script-bar-widget/` | `stochi` | Thin QML + an executable helper script |

Also read `reference/README.md`. Prefer copying a sample and editing it over
writing from scratch.

Authoritative sources on the machine:

- `$OMARCHY_PATH/shell/README.md` — manifest, IPC, `shell.json`
- `$OMARCHY_PATH/shell/plugins/README.md` — first-party catalogue
- `$OMARCHY_PATH/shell/Ui/BarWidget.qml`, `Ui/Panel.qml` — base classes
- `$OMARCHY_PATH/shell/Ui/PluginBarApi.qml`, `services/PluginShellApi.qml` — scoped APIs
- `$OMARCHY_PATH/bin/omarchy-plugin-validate` — validation rules
- Official guide: <https://plugins.omarchy.org/develop.html>
- Built-in examples: <https://github.com/omacom/omarchy/tree/quattro/shell/plugins>

Recommended first move: `omarchy plugin clone omarchy.clock --edit` and adapt
the clone, keeping its printed id while developing.

## Step 1 — Interview (ask before writing)

Ask in grouped batches. Do not write files until the user confirms the summary,
unless they say "just build it".

**Identity:** id (namespaced, e.g. `io.github.yourname.pomodoro`; `omarchy.*`
reserved), name, author, license (default MIT), version (default `0.1.0`),
one-line description, category, aliases, `allowMultiple`.

**Purpose:** what it does; trigger (visible/timer/click/keybind/summon); data
source (local command, file, network API, none); if network — endpoint and
keyless vs auth; where any credential lives (never in the repo); external
dependencies; refresh cadence; failure modes to handle.

**Bar shape:** icon (Nerd Font glyph) or text; static or dynamic label;
color/state variants (normal/active/urgent/dim); tooltip; left/right/middle
click and scroll actions; default section (`left`/`center`/`right`); width
behavior; vertical-bar fallback.

**Expanded shape:** does it expand at all; kind (`panel` floating, `overlay`
fullscreen, `menu`); size and placement; layout (list/form/detail/tabs/chart);
sections and order; keyboard navigation; open/close behavior (Esc, scrim,
focus, `keepLoaded`); summon method and suggested Hyprland keybind; whether it
writes anything back.

**Settings:** for each tunable — key, type (`string`|`integer`|`boolean`|`enum`|
`path`|`multiselect`), label, default, and min/max/step/options/description.

**Language:** QML+JS only, or a helper script? If a helper, which language —
**recommend Python or Bash**, but honor an explicit user choice — and what
dependencies.

**Repo:** target directory, git URL / whether to `git init`, CI, tests,
screenshots.

## Step 2 — Map answers to architecture

| Need | Kind(s) | Entry point(s) | Notes |
|---|---|---|---|
| Always-visible bar item | `bar-widget` | `barWidget` | Extend `BarWidget`; set `moduleName`. |
| Bar item + drop-down | `bar-widget` | `barWidget` | Widget loads `Panel.qml` internally. Do **not** add a `panel` kind. |
| Keybind/IPC floating window | `panel` | `panel` | `Item` + `PanelWindow` layer surface. |
| Fullscreen picker/search | `overlay` | `overlay` | Same as panel, full-screen scrim; `keepLoaded` if reused. |
| Summoned menu | `menu` | `menu` | Model after `omarchy.menu`. |
| Headless polling/shared state | `service` | `service` | `Process` + `Timer`; emit signals. |
| Replace the bar | `bar` | `bar` | Study `Bar.qml`; one active at a time. |

Put heavy logic in a helper script and keep QML thin.

## Step 3 — Generate

Create this tree (drop optional files only if declined):

```
<plugin-dir>/
├── manifest.json
├── <BarWidget|Panel|Overlay|Service|Bar>.qml
├── Panel.qml                # nested panel for a bar widget, if it expands
├── Model.js                 # pure, testable logic if non-trivial
├── <helper>                 # if chosen (chmod +x)
├── Makefile
├── README.md
├── LICENSE
├── .gitignore
├── .github/workflows/ci.yml # if requested
└── tests/                   # if requested
```

### Hard rules

- `schemaVersion` is exactly the number `1`.
- `id` is namespaced; never `omarchy.*`. Reverse-DNS (`io.github.you.x`) is a
  good convention for published plugins.
- Every declared kind has its matching `entryPoints` key:
  `bar-widget:barWidget`, `panel:panel`, `overlay:overlay`, `menu:menu`,
  `service:service`, `bar:bar`.
- A bar widget with a drop-down is **one** `bar-widget` kind. `BarWidget.qml`
  loads `Panel.qml` internally; both share `moduleName`; do not declare a
  second `panel` kind for a nested panel.
- The bar widget forwards `opened`, `open()`, `close()`, `toggle()`, and
  `closeForPopoutSwitch()` to the loaded panel, and calls `injectPanel()` on
  `onBarChanged`/`onSettingsChanged` to set `bar`, `settings`, `anchorItem`,
  `hostWidget`.
- Nested `Panel.qml` sets `manageIpc: false`; a standalone panel/overlay owns
  its lifecycle and IPC.
- `PanelKeyCatcher` closes via `onCloseRequested`, switches via
  `onTabRequested`, moves via `onMoveRequested` — there is no `onEscape`.
- Buttons are `WidgetButton` with `onPressed: function(button) { ... }`.
- `barWidget.defaultSection` ∈ {`left`,`center`,`right`}.
- Theme only through `qs.Commons` singletons (`Color`, `Style`, `Border`,
  `Util`). No hardcoded theme colors (fixed colors only for deliberate fixed
  surfaces, with a comment).
- Read settings with `setting("key", fallback)`; persist by copying the entry
  and calling `shell.updateEntryInline(id, entry)`. Never edit `shell.json`
  directly.
- Shell-quote interpolated arguments with `Util.shellQuote()`.
- No symlinks and no absolute paths in `entryPoints`.
- Helper scripts: executable + shebang; resolve path from QML via
  `decodeURIComponent(String(Qt.resolvedUrl("helper")).replace(/^file:\/\//, ""))`;
  JSON on stdout, errors on stderr; no secrets.
- Never edit `$OMARCHY_PATH/shell/plugins/` and never start a second Quickshell
  process for a plugin.

### Manifest skeleton

```json
{
  "schemaVersion": 1,
  "id": "io.github.yourname.sample",
  "name": "Sample",
  "version": "0.1.0",
  "author": "Your Name",
  "license": "MIT",
  "description": "One line.",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "Sample",
    "category": "Utilities",
    "allowMultiple": false,
    "defaultSection": "right",
    "defaults": { "refreshIntervalSec": 300 },
    "schema": [
      { "key": "refreshIntervalSec", "type": "integer",
        "label": "Refresh interval (seconds)", "min": 60, "max": 3600,
        "step": 60, "defaultValue": 300 }
    ]
  }
}
```

### `BarWidget.qml` (with nested panel)

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.yourname.sample"

  property string output: ""

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open()  { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function refresh() { if (!proc.running) proc.running = true }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  IpcHandler {
    target: "io.github.yourname.sample"
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Process {
    id: proc
    command: ["date", "+%H:%M:%S"]
    stdout: SplitParser { onRead: line => root.output = line }
  }

  Timer {
    interval: Math.max(60, Number(setting("refreshIntervalSec", 300))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.output
    tooltipText: "Open sample details"
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }
  }
}
```

### `Panel.qml` (nested)

```qml
import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.yourname.sample"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open()  { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)
        Text {
          width: parent.width
          text: "Panel content"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
```

### `Service.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var shell: null
  signal changed(string value)
  property string value: ""

  function refresh() { if (!proc.running) proc.running = true }

  Process {
    id: proc
    command: ["date", "+%s"]
    stdout: SplitParser { onRead: line => { root.value = line; root.changed(line) } }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
```

### `Makefile`

```make
.PHONY: test unit lint validate
test: unit lint validate
unit:
	node tests/test_model.js
	python -m unittest discover -s tests -v
lint:
	qmllint -I "$OMARCHY_PATH/shell" ./*.qml
validate:
	omarchy plugin validate .
	jq -e . manifest.json >/dev/null
```

Adjust `unit` to the chosen languages; drop inapplicable targets.

## Step 4 — Self-check and hand off

Run and confirm:

- `omarchy plugin validate <dir>`
- `jq -e . manifest.json`
- `qmllint -I "$OMARCHY_PATH/shell" <dir>/*.qml`
  (if `qmllint` is not on PATH, use `/usr/lib/qt6/bin/qmllint`). Warnings about
  importing `qs.Commons`/`qs.Ui` are expected — qmllint does not know
  Quickshell's `qs` alias. Only errors matter.
- Helper runs standalone and prints valid JSON
- Unit tests pass (if generated)
- `omarchy plugin list --json | jq '.[] | select(.id=="<id>")'` shows the id
  with the expected kind and `enabled: true`
- README documents install, usage, settings, dependencies, dev loop
- `LICENSE` and `.gitignore` exist

Then print:

```bash
omarchy plugin add "$PWD" --enable --yes
# if it does not appear:
omarchy-shell shell rescanPlugins
# QML errors:
qs log -p "$OMARCHY_PATH/shell" --tail 100   # or: journalctl -t omarchy-shell -f
```

## Troubleshooting (hand back to the user)

- **Folder not found** — use the exact id printed by `omarchy plugin clone`.
- **Entry point file not found** — `entryPoints` value must match the filename
  and capitalization on disk.
- **Validates but not listed** — `omarchy-shell shell rescanPlugins`, then
  `omarchy plugin list --json`.
- **Listed but invisible** — enable it, confirm the kind, inspect `qs log`.
- **Panel opens once but not again** — forward `opened`, `open()`, and
  `close()` from the bar entry point to the loaded panel.

## Guardrails

- Ask before assuming; honor the user's explicit helper-language choice.
- Never invent endpoints, CLI flags, or QML APIs.
- Flag auth/token/command-execution decisions for approval.
- Do not commit unless asked.
