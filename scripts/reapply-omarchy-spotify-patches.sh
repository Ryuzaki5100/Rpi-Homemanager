#!/usr/bin/env bash
# Reapply the local Omarchy Spotify plugin patches after `omarchy plugin update`.
#
# Omarchy 4.0.3+ strips __sourceDir from third-party plugin manifests and no
# longer exposes shell.shellConfig to them (omacom/omarchy#10863). The upstream
# plugin still reads both, so it silently breaks: setup hangs on "Checking
# local playback", and the shortcut falls back to "omarchy launch spotify"
# (the desktop-client installer). This reapplies the two-part workaround to
# Service.qml. Idempotent: a no-op when already patched or fixed upstream.
#
# Usage: reapply-omarchy-spotify-patches.sh [--check] [--restart]
#   --check     report status only, change nothing
#   --restart   run `omarchy restart shell` after patching
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

PLUGIN_DIR="${OMARCHY_SPOTIFY_PLUGIN_DIR:-$HOME/.config/omarchy/plugins/quickshell.spotify}"
SERVICE="$PLUGIN_DIR/Service.qml"

check_only=false
restart=false
for arg in "$@"; do
  case $arg in
    --check)   check_only=true ;;
    --restart) restart=true ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "reapply-omarchy-spotify-patches: unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Portable: only relevant where the plugin is installed (e.g. skip on the Pi).
if [ ! -f "$SERVICE" ]; then
  echo "reapply-omarchy-spotify-patches: $SERVICE not found; nothing to do."
  exit 0
fi

have python3 || { echo "reapply-omarchy-spotify-patches: python3 is required" >&2; exit 1; }

status=0
python3 - "$SERVICE" "$check_only" <<'PY' || status=$?
import sys

path, check_only = sys.argv[1], sys.argv[2] == "true"
text = open(path, encoding="utf-8").read()

ORIG1 = (
    '  readonly property string pluginDir: manifest && manifest.__sourceDir\n'
    '    ? String(manifest.__sourceDir) : ""\n'
)
NEW1 = (
    '  // Omarchy 4.0.3+ strips __sourceDir from third-party plugin manifests\n'
    '  // (omacom/omarchy#10863), so fall back to resolving this component\'s own\n'
    '  // directory from its file URL.\n'
    '  readonly property string pluginDir: {\n'
    '    var dir = manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""\n'
    '    if (dir) return dir\n'
    '    return decodeURIComponent(Qt.resolvedUrl(".").toString()\n'
    '      .replace(/^file:\\/\\//, "")).replace(/\\/$/, "")\n'
    '  }\n'
)
ORIG2 = (
    '  function configuredEntry() {\n'
    '    var config = shell && shell.shellConfig ? shell.shellConfig : null\n'
)
NEW2 = (
    '  function configuredEntry() {\n'
    '    // Omarchy 4.0.3+ no longer exposes shell.shellConfig to third-party plugins\n'
    '    // (omacom/omarchy#10863), so fall back to shell.barConfig, which carries the\n'
    '    // same bar subtree and stays live.\n'
    '    var barConfig = shell && shell.barConfig ? shell.barConfig : null\n'
    '    var config = barConfig ? ({ bar: barConfig })\n'
    '      : (shell && shell.shellConfig ? shell.shellConfig : null)\n'
)
patched1, patched2 = NEW1 in text, NEW2 in text

if patched1 and patched2:
    print("Service.qml is already patched (or fixed upstream); nothing to do.")
    sys.exit(10)

todo = []
if not patched1:
    if ORIG1 not in text:
        print("Service.qml changed upstream: cannot find the pluginDir block. "
              "Manual review needed.", file=sys.stderr)
        sys.exit(1)
    todo.append("pluginDir fallback")
if not patched2:
    if ORIG2 not in text:
        print("Service.qml changed upstream: cannot find configuredEntry(). "
              "Manual review needed.", file=sys.stderr)
        sys.exit(1)
    todo.append("configuredEntry barConfig fallback")

if check_only:
    print("Not patched. Would apply: " + ", ".join(todo))
    sys.exit(20)

new = text.replace(ORIG1, NEW1).replace(ORIG2, NEW2)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    fh.write(new)
import os
os.replace(tmp, path)
print("Patched Service.qml: " + ", ".join(todo))
PY

case $status in
  0)  if [ "$restart" = true ]; then
        omarchy restart shell
        echo "Restarted the shell."
      fi ;;
  10) exit 0 ;;
  20) exit 0 ;;
  *)  exit "$status" ;;
esac
