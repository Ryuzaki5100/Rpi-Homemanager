#!/bin/sh
# Locate and exec Roblox Studio's bundled MCP server.
#
# Committed so any MCP client can reference a stable name
# (`roblox-studio-mcp`) instead of an absolute .app path. Identical logic is
# installed globally by the darwin home-manager module.
set -eu

macos_studio="/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"

if [ -x "$macos_studio" ]; then
	exec "$macos_studio"
fi

if [ -n "${LOCALAPPDATA:-}" ] && [ -f "$LOCALAPPDATA/Roblox/mcp.bat" ]; then
	exec cmd.exe /c "$LOCALAPPDATA/Roblox/mcp.bat"
fi

echo "roblox-studio-mcp: Roblox Studio MCP server not found; is Roblox Studio installed?" >&2
exit 1
