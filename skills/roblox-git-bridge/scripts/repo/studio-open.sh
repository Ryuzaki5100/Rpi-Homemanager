#!/bin/sh
# Open the canonical place in Roblox Studio.
#
#   studio-open            tracked local place (default: geometry lives here)
#   studio-open --cloud    the published place (needs placeId/universeId)
#
# Local is the default because MCP `save_place` only writes to disk for local
# places; a cloud place saves a cloud version, which git never sees.
#
# Launching notes (learned the hard way, keep them):
#   - `open -a RobloxStudio <file>` does NOT load the place when invoked this
#     way; Studio comes up with "Place is not open".
#   - Running the binary with --task EditFile/EditPlace DOES load it.
#   - Launch exactly one Studio per place, and detach with nohup so the instance
#     survives the shell that started it.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

studio="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"

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

[ -x "$studio" ] || {
	echo "studio-open: Roblox Studio not found at $studio" >&2
	exit 1
}

place_file=${ROBLOX_PLACE_FILE:-$(jq -r .placeFile roblox.json)}
place_id=${ROBLOX_PLACE_ID:-$(jq -r '.game.placeId // empty' roblox.json)}
universe_id=${ROBLOX_UNIVERSE_ID:-$(jq -r '.game.universeId // empty' roblox.json)}

if [ "$mode" = cloud ]; then
	[ -n "$place_id" ] || { echo "studio-open: no game.placeId in roblox.json" >&2; exit 1; }
	[ -n "$universe_id" ] || { echo "studio-open: no game.universeId in roblox.json" >&2; exit 1; }
	nohup "$studio" --task EditPlace --placeId "$place_id" --universeId "$universe_id" \
		>/dev/null 2>&1 &
	echo "studio-open: launched cloud place $place_id"
	exit 0
fi

[ -f "$place_file" ] || {
	echo "studio-open: $place_file is missing; run 'rojo build default.project.json -o $place_file'" >&2
	exit 1
}
nohup "$studio" --task EditFile --localPlaceFile "$ROOT/$place_file" >/dev/null 2>&1 &
echo "studio-open: launched $place_file"
