#!/bin/sh
# Check that this machine and repository can actually run the Studio bridge.
# Exit code 0 means everything required is present.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

failed=0
ok() { printf '  ok    %s\n' "$1"; }
bad() {
	printf '  MISS  %s\n' "$1"
	failed=1
}

echo "tools"
for tool in rojo selene stylua luau-lsp lune git jq; do
	if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else bad "$tool"; fi
done

echo "studio"
if [ -x /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP ]; then
	ok "StudioMCP binary"
else
	bad "StudioMCP binary (install Roblox Studio)"
fi
if [ -f "$HOME/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm" ]; then
	ok "Rojo plugin"
else
	bad "Rojo plugin (run 'rojo plugin install', then restart Studio)"
fi

echo "repository"
[ -f roblox.json ] && ok "roblox.json" || bad "roblox.json"
if command -v jq >/dev/null 2>&1 && [ -f roblox.json ]; then
	name=$(jq -r '.game.name // empty' roblox.json)
	[ -n "$name" ] && ok "game name: $name" || bad "game.name empty in roblox.json"

	place_file=$(jq -r .placeFile roblox.json)
	[ -f "$place_file" ] && ok "place file: $place_file" || bad "place file missing ($place_file)"
fi
if git remote get-url origin >/dev/null 2>&1; then ok "git remote"; else bad "git remote origin"; fi
if grep -q "$(jq -r .sentinel roblox.json | sed 's/.*\.//')" default.project.json 2>/dev/null; then
	ok "sentinel mapped in project"
else
	bad "sentinel not found in default.project.json"
fi

exit "$failed"
