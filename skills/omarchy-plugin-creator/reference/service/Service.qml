import QtQuick
import Quickshell
import Quickshell.Io

// Headless service: loaded at startup, no UI. Other plugins read `value` or
// connect to `changed`. A service can also be paired with a bar-widget in the
// same plugin by declaring both kinds.
Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property string value: ""
  signal changed(string value)

  function refresh() {
    if (!proc.running) proc.running = true
  }

  Process {
    id: proc
    command: ["date", "+%s"]
    stdout: SplitParser {
      onRead: line => {
        root.value = line
        root.changed(line)
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
