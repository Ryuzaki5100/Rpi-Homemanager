#!/bin/sh
# Report the git side of the three-way state: HEAD vs working tree vs origin.
#
# The Studio side cannot be seen from here; the agent compares each mapped
# script in Studio against disk (script_read) and applies the same rule.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

branch=$(git rev-parse --abbrev-ref HEAD)
if git fetch --quiet origin "$branch" 2>/dev/null; then
	have_remote=1
else
	have_remote=0
fi

dirty=$(git status --porcelain | wc -l | tr -d ' ')
ahead=0
behind=0
if [ "$have_remote" -eq 1 ]; then
	set -- $(git rev-list --left-right --count "origin/$branch...HEAD")
	behind=$1
	ahead=$2
fi

place_file=$(jq -r .placeFile roblox.json)
place_state=missing
[ -f "$place_file" ] && place_state="$(wc -c <"$place_file" | tr -d ' ') bytes"

printf 'branch        %s\n' "$branch"
printf 'working tree  %s\n' "$([ "$dirty" -eq 0 ] && echo clean || echo "$dirty changed path(s)")"
printf 'remote        %s ahead, %s behind origin/%s\n' "$ahead" "$behind" "$branch"
printf 'place file    %s (%s)\n' "$place_file" "$place_state"

if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
	echo "state         DIVERGED - halt, resolve manually, never force-push"
	exit 1
elif [ "$behind" -gt 0 ]; then
	echo "state         local behind GitHub - pull needed before editing"
elif [ "$dirty" -gt 0 ] || [ "$ahead" -gt 0 ]; then
	echo "state         local ahead - commit and push"
else
	echo "state         in sync with GitHub"
fi
