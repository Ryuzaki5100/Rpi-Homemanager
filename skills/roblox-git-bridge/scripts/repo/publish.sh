#!/bin/sh
# Publish the project to the Roblox place named in roblox.json.
#
# Requires an Open Cloud API key with place:write, exported as ROBLOX_API_KEY.
# Refuses to publish from a dirty working tree so the published build always
# corresponds to a commit.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

: "${ROBLOX_API_KEY:?publish: set ROBLOX_API_KEY to an Open Cloud API key with place:write}"

place_id=${ROBLOX_PLACE_ID:-$(jq -r '.game.placeId // empty' roblox.json)}
universe_id=${ROBLOX_UNIVERSE_ID:-$(jq -r '.game.universeId // empty' roblox.json)}

[ -n "$place_id" ] || { echo "publish: no game.placeId in roblox.json" >&2; exit 1; }
[ -n "$universe_id" ] || { echo "publish: no game.universeId in roblox.json" >&2; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
	echo "publish: working tree is dirty; commit first so the build matches a revision" >&2
	git status --short
	exit 1
fi

echo "publish: building and uploading to place $place_id (universe $universe_id)"
exec rojo upload \
	--api_key "$ROBLOX_API_KEY" \
	--universe_id "$universe_id" \
	--asset_id "$place_id" \
	default.project.json
