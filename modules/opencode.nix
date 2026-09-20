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
          enabled = true;
          command = [ "uv" "run" "--no-project" "--with" "mcp-google-gmail" "--with" "mcp>=1.8.0,<2" "mcp-google-gmail" ];
          environment = {
            GMAIL_CREDENTIALS_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/credentials.json";
            GMAIL_TOKEN_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/token.json";
          };
        };
      };
    };

    # "omarchy" is generated at runtime from the active Omarchy theme by
    # scripts/opencode-omarchy-theme.sh; do not manage opencode/themes here.
    # Non-Omarchy hosts keep the default theme (no tui.json is written).
    tui = lib.mkIf config.host.isOmarchy {
      theme = "omarchy";
    };
  };

  xdg.configFile = skillConfigs // lib.optionalAttrs config.host.isOmarchy {
    # Palette generator, invoked by the theme-set hook and the fish wrapper.
    "opencode/omarchy-theme.sh".source = ../scripts/opencode-omarchy-theme.sh;

    # Regenerate the opencode theme after every `omarchy theme set`, then
    # re-signal opencode. Omarchy signals opencode *before* hooks run, so the
    # file would otherwise still hold the previous palette.
    "omarchy/hooks/theme-set.d/opencode-theme.hook".text = ''
      #!/usr/bin/env bash
      # Regenerate the opencode theme after every `omarchy theme set`, then
      # re-signal opencode. Omarchy signals opencode *before* hooks run, so the
      # file would otherwise still hold the previous palette.
      bash "$HOME/.config/opencode/omarchy-theme.sh" || exit 0
      command -v omarchy-restart-opencode >/dev/null 2>&1 && omarchy-restart-opencode || true
    '';
  };
}
