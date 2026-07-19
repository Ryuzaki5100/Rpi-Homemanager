{ config, pkgs, ... }:

let
  gmailDir = "${config.home.homeDirectory}/.config/gmail-mcp";
in
{
  home.packages = [ pkgs.uv ];

  programs.opencode = {
    enable = true;
    settings = {
      mcp = {
        gmail = {
          type = "local";
          enabled = false;
          command = [ "uvx" "mcp-google-gmail@latest" ];
          environment = {
            GMAIL_CREDENTIALS_PATH = "${gmailDir}/credentials.json";
            GMAIL_TOKEN_PATH = "${gmailDir}/token.json";
          };
        };
      };
    };
  };
}
