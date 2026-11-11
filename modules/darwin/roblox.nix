{ pkgs, ... }:

# Roblox game development on macOS.
#
# Roblox Studio is deliberately *not* packaged here: it installs and updates
# itself from Roblox's own installer at a fixed path, and its bundled MCP server
# lives inside the .app. Everything on our side of that boundary is pinned by
# nixpkgs instead: the Luau toolchain, the Studio MCP registration, and the
# language server OpenCode drives.
let
  studioMacOS = "/Applications/RobloxStudio.app/Contents/MacOS";

  # luau-lsp takes --sourcemap/--definitions only when the files exist; passing
  # a missing path makes it fail at startup. The wrapper keeps one global LSP
  # entry valid across repos that have not been scaffolded (or synced) yet.
  luauLsp = pkgs.writeShellScriptBin "luau-lsp-roblox" ''
    args=()
    [ -f sourcemap.json ] && args+=("--sourcemap=sourcemap.json")
    [ -f globalTypes.d.luau ] && args+=("--definitions=globalTypes.d.luau")
    exec ${pkgs.luau-lsp}/bin/luau-lsp lsp "''${args[@]}"
  '';

  # Stable command name for the Studio MCP server, so project-level OpenCode
  # configs can reference `roblox-studio-mcp` instead of hardcoding an absolute
  # .app path. Repos also provide this name through their own devenv.
  studioMcp = pkgs.writeShellScriptBin "roblox-studio-mcp" ''
    if [ -x "${studioMacOS}/StudioMCP" ]; then
      exec "${studioMacOS}/StudioMCP"
    fi
    if [ -n "''${LOCALAPPDATA:-}" ] && [ -f "$LOCALAPPDATA/Roblox/mcp.bat" ]; then
      exec cmd.exe /c "$LOCALAPPDATA/Roblox/mcp.bat"
    fi
    echo "roblox-studio-mcp: Roblox Studio MCP server not found; is Roblox Studio installed?" >&2
    exit 1
  '';
in {
  home.packages = with pkgs; [
    rojo # filesystem <-> Studio project mapping, serve/build/upload
    selene # Luau linter
    stylua # Luau formatter
    luau-lsp # language server (registered with OpenCode below)
    luau # interpreter for one-off checks
    lune # Luau scripting / test runner
    luauLsp
    studioMcp

    # wally is intentionally absent: nixpkgs marks it badPlatforms on
    # aarch64-darwin. If a project needs Luau packages, pin wally's prebuilt
    # darwin release in that project's devenv instead of forcing it here.
  ];

  programs.opencode.settings = {
    # Studio MCP server. Requires Roblox Studio to be open with
    # Assistant -> ... -> Manage MCP Servers -> "Enable Studio as MCP server".
    mcp.servers.roblox = {
      type = "local";
      command = [ "roblox-studio-mcp" ];
      codemode = true;
      # Studio enumerates ~25 tools on startup, and mesh/playtest jobs run for
      # minutes. The 5s default is too tight on both ends.
      timeout = {
        startup = 60000;
        catalog = 120000;
        execution = 300000;
      };
    };

    lsp.luau-lsp = {
      command = [ "luau-lsp-roblox" ];
      extensions = [ ".luau" ".lua" ];
    };
  };
}
