import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Standalone `panel` kind. Unlike a nested bar-widget panel, this owns its
// own layer-shell surface via PanelWindow and is summoned directly by the
// shell (`omarchy-shell shell summon yourname.panel '{"message":"hi"}'`).
Item {
  id: root

  // Injected by the host for panel/overlay/menu kinds.
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string message: ""

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.message = String(payload.message || "")
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  // User-initiated dismissal routes through shell.hide so the host's
  // open-panel bookkeeping stays consistent.
  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "yourname.panel")
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yourname-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Color.popups.background
      opacity: 0.6

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(Style.space(420), keyCatcher.width - Style.space(32))
        height: body.implicitHeight + Style.spacing.popupPadding * 2
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: Math.max(1, Style.spacing.hairline)
        border.color: Color.popups.border

        // Swallow clicks so only the scrim outside dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
          id: body
          anchors.fill: parent
          anchors.margins: Style.spacing.popupPadding
          text: root.message !== "" ? root.message : "Standalone panel"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
