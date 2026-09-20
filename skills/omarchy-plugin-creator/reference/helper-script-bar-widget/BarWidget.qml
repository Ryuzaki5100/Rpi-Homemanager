import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Thin QML: it only renders and spawns the helper. All logic lives in
// `sample-fetch`, which prints JSON on stdout.
BarWidget {
  id: root
  moduleName: "yourname.helper-sample"

  property string output: ""

  // Resolve the helper next to this QML file. Never hardcode an absolute path.
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("sample-fetch")).replace(/^file:\/\//, "")
  )

  function refresh() {
    if (!proc.running) proc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "yourname.helper-sample"
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: proc
    command: [root.helperPath]
    stdout: SplitParser {
      onRead: line => {
        try {
          var data = JSON.parse(line)
          root.output = String(data.value || "")
        } catch (e) {
          console.warn("helper-sample: bad JSON:", line)
        }
      }
    }
  }

  Timer {
    interval: Math.max(60, Number(setting("refreshIntervalSec", 300))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.output
    tooltipText: "Helper sample"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.refresh()
    }
  }
}
