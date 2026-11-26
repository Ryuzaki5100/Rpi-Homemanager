# MCP servers, defined once (ai/mcp.nix) and rendered into the two shapes.
{ config, lib, pkgs, ... }:

let
  servers = import ../../ai/mcp.nix {
    inherit pkgs;
    home = config.home.homeDirectory;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  };
in
{
  # OpenCode 2: `mcp.servers.<name>`, with `codemode` and object-shaped timeouts
  # validated against the schema at build time by programs.opencode.
  programs.opencode.settings.mcp.servers = lib.mapAttrs (_: server: server.opencode) servers;

  # Claude Code: .mcp.json entries. File-backed secrets are wrapped in a script
  # by ai/mcp.nix because Claude Code has no `{file:…}` substitution.
  programs.claude-code.mcpServers = lib.mapAttrs (_: server: server.claude) servers;
}
