#!/bin/sh
# Scaffold a Roblox <-> git bridge into an existing repository.
#
#   bootstrap.sh --dry-run --name "Game Name" --slug game-slug [--repo repo-name]
#   bootstrap.sh           --name "Game Name" --slug game-slug [--repo repo-name]
#
# Idempotent: an existing file is never overwritten. Dry-run prints the plan and
# touches nothing - run it first and show the user.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
templates="$here/../templates"

dry_run=0
name=
slug=
repo=

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) dry_run=1; shift ;;
		--name) name=${2:-}; shift 2 ;;
		--slug) slug=${2:-}; shift 2 ;;
		--repo) repo=${2:-}; shift 2 ;;
		-h|--help)
			echo "usage: bootstrap.sh [--dry-run] --name 'Game Name' --slug game-slug [--repo repo-name]"
			exit 0
			;;
		*)
			echo "bootstrap: unknown argument $1" >&2
			exit 2
			;;
	esac
done

[ -n "$name" ] || { echo "bootstrap: --name is required" >&2; exit 2; }
[ -n "$slug" ] || { echo "bootstrap: --slug is required" >&2; exit 2; }
[ -n "$repo" ] || repo=$(basename "$(pwd)")

# CamelCase prefix for the sentinel and starter scripts: noclip-protocol -> NoclipProtocol
prefix=$(printf '%s' "$slug" | awk -F- '{ for (i = 1; i <= NF; i++) printf toupper(substr($i, 1, 1)) substr($i, 2) }')

plan() {
	printf '  %-34s %s\n' "$1" "$2"
}

emit() {
	# emit <path> <template> [sed expressions...]
	path=$1
	template=$2
	shift 2
	if [ -f "$path" ]; then
		plan "$path" "exists, left alone"
		return 0
	fi
	if [ "$dry_run" -eq 1 ]; then
		plan "$path" "would create"
		return 0
	fi
	mkdir -p "$(dirname "$path")"
	if [ $# -gt 0 ]; then
		sed "$@" "$template" >"$path"
	else
		cp "$template" "$path"
	fi
	plan "$path" "created"
}

echo "repository: $(pwd)"
echo "game:       $name"
echo "slug:       $slug"
echo "sentinel:   ServerScriptService.${prefix}Boot"
echo ""

plan "roblox.json" "identity"
emit roblox.json "$templates/roblox.json" \
	-e "s|<repo-name>|$repo|g" \
	-e "s|<game-slug>|$slug|g" \
	-e "s|<Game Display Name>|$name|g" \
	-e "s|<Name>|$prefix|g"

plan "default.project.json" "Rojo mapping"
emit default.project.json "$templates/default.project.json" \
	-e "s|<game-slug>|$slug|g" \
	-e "s|<Name>|$prefix|g"

plan "devenv.nix" "pinned toolchain"
emit devenv.nix "$templates/devenv.nix"

plan "devenv.yaml" "nixpkgs input"
if [ -f devenv.yaml ]; then
	plan "devenv.yaml" "exists, left alone"
elif [ "$dry_run" -eq 1 ]; then
	plan "devenv.yaml" "would create"
else
	printf 'inputs:\n  nixpkgs:\n    url: github:cachix/devenv-nixpkgs/rolling\n' >devenv.yaml
	plan "devenv.yaml" "created"
fi

plan "AGENTS.md" "agent contract"
emit AGENTS.md "$templates/AGENTS.md"

plan ".opencode/opencode.json" "MCP server by name"
if [ -f .opencode/opencode.json ]; then
	plan ".opencode/opencode.json" "exists, left alone"
elif [ "$dry_run" -eq 1 ]; then
	plan ".opencode/opencode.json" "would create"
else
	mkdir -p .opencode
	cat >.opencode/opencode.json <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "roblox": {
        "type": "local",
        "command": ["roblox-studio-mcp"],
        "codemode": true,
        "timeout": { "startup": 60000, "catalog": 120000, "execution": 300000 }
      }
    }
  }
}
JSON
	plan ".opencode/opencode.json" "created"
fi

for script in studio-mcp.sh studio-open.sh status.sh sync.sh preflight.sh publish.sh; do
	target="scripts/$script"
	if [ -f "$target" ]; then
		plan "$target" "exists, left alone"
	elif [ "$dry_run" -eq 1 ]; then
		plan "$target" "would copy"
	else
		mkdir -p scripts
		cp "$here/repo/$script" "$target"
		chmod +x "$target"
		plan "$target" "copied"
	fi
done

if [ "$dry_run" -eq 1 ]; then
	echo ""
	echo "dry run: nothing written. Re-run without --dry-run to apply."
	exit 0
fi

echo ""
echo "next:"
echo "  1. devenv test                      # pins the toolchain, builds once"
echo "  2. rojo build default.project.json -o place/$slug.rbxlx"
echo "  3. studio-open && connect the Rojo plugin"
echo "  4. preflight                        # expect all ok"
echo "  5. git add -A && git commit -m 'feat: scaffold $name with Rojo'"
