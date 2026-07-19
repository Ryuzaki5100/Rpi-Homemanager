{ config, pkgs, lib, ... }:

let
  skillsDir = ../skills;
  skillDirs = builtins.readDir skillsDir;
  skillNames = builtins.attrNames (lib.filterAttrs (name: type: type == "directory") skillDirs);
  skillConfigs = builtins.listToAttrs (builtins.map
    (name: {
      name = "opencode/skills/${name}/SKILL.md";
      value.source = "${skillsDir}/${name}/SKILL.md";
    })
    skillNames);
in {
  programs.opencode = {
    enable = true;
    settings = {
      model = "opencode/deepseek-v4-flash-free";
      mcp = {
        gmail = {
          type = "local";
          enabled = false;
          command = [ "uvx" "mcp-google-gmail@latest" ];
          environment = {
            GMAIL_CREDENTIALS_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/credentials.json";
            GMAIL_TOKEN_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/token.json";
          };
        };
      };
    };
  };

  xdg.configFile = skillConfigs;
}
