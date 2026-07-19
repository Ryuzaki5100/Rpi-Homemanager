{ pkgs, ... }: {
  home.packages = [ pkgs.uv pkgs.gmail-mcp-auth ];
}
