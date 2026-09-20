import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry point. Owns the label, the IPC, and the bar identity, and loads
// the nested Panel.qml. This is ONE bar-widget plugin: Panel.qml is not a
// separate declared kind.
BarWidget {
  id: root
  moduleName: "yourname.sample"

  property string output: ""

  // The bar routes summon/hide/toggle through these names, so forward the
  // panel lifecycle from the widget that the bar actually mounted.
  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }
  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }
  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function refresh() {
    if (!proc.running) proc.running = true
  }

  // Guarded with `in` because the panel may render before the bar injects
  // host state (the bar-widget contract instantiates the widget bare).
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
    target: "yourname.sample"

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
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.output
    tooltipText: "Open sample details"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }
}
