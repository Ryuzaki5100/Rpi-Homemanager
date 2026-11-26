# Firecrawl MCP server: npx needs Node, and the server itself is defined once
# in ai/mcp.nix (modules/common/mcp.nix renders it for both tools).
{ pkgs, ... }:

{
  home.packages = [ pkgs.nodejs ];
}
