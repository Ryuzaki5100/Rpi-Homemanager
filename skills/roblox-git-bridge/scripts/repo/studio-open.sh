#!/bin/sh
# Open the canonical place in Roblox Studio.
#
#   studio-open            tracked local place (default: geometry lives here)
#   studio-open --cloud    the published place (needs placeId/universeId)
#
# Local is the default because MCP `save_place` only writes to disk for local
# places; a cloud place saves a cloud version, which git never sees.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

mode=local
case "${1:-}" in
	""|--local) mode=local ;;
	--cloud) mode=cloud ;;
	-h|--help)
		echo "usage: studio-open [--local|--cloud]"
		exit 0
		;;
	*)
		echo "studio-open: unknown argument $1" >&2
		exit 2
		;;
esac

place_file=${ROBLOX_PLACE_FILE:-$(jq -r .placeFile roblox.json)}
place_id=${ROBLOX_PLACE_ID:-$(jq -r '.game.placeId // empty' roblox.json)}
universe_id=${ROBLOX_UNIVERSE_ID:-$(jq -r '.game.universeId // empty' roblox.json)}

if [ "$(uname -s)" != Darwin ]; then
	echo "studio-open: only macOS is wired up so far" >&2
	exit 1
fi

if [ "$mode" = cloud ]; then
	[ -n "$place_id" ] || { echo "studio-open: no game.placeId in roblox.json" >&2; exit 1; }
	[ -n "$universe_id" ] || { echo "studio-open: no game.universeId in roblox.json" >&2; exit 1; }
	# Launching the binary with a task opens a session for that place. Do not
	# also open the file: two launches leave one instance at "Place is not open".
	"/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio" \
		--task EditPlace --placeId "$place_id" --universeId "$universe_id" \
		>/dev/null 2>&1 &
	echo "studio-open: launched cloud place $place_id (close other Studio windows first)"
	exit 0
fi

[ -f "$place_file" ] || {
	echo "studio-open: $place_file is missing; run 'rojo build default.project.json -o $place_file'" >&2
	exit 1
}
# Proven path: hand the file to LaunchServices as an argument. The
# `--args --task EditFile` form silently fails to load the place when Studio is
# already running.
exec open -a RobloxStudio "$ROOT/$place_file"
