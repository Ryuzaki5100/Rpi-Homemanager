{ config, pkgs, ... }:

{
  home.packages = [ pkgs.nodejs ];

  programs.opencode.settings.mcp.servers.firecrawl = {
    type = "local";
    command = [ "npx" "-y" "firecrawl-mcp@3.23.8" ];
    environment = {
      FIRECRAWL_API_KEY = "{file:${config.home.homeDirectory}/.config/firecrawl/api-key}";
    };
  };
}
