{ config, lib, ... }:

let
  inherit (lib)
    attrNames
    concatStringsSep
    filterAttrs
    hasSuffix
    map
    removeSuffix
    ;

  # Every JSON in glow/themes/ becomes a selectable glow theme. Adding a file
  # here and rebuilding makes it appear in `glow-set-theme` automatically.
  themesDir = ../glow/themes;
  themeFiles = filterAttrs (name: type: type == "regular" && hasSuffix ".json" name) (
    builtins.readDir themesDir
  );
  themeNames = map (removeSuffix ".json") (attrNames themeFiles);

  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/glow";
  themesDirOut = "${configDir}/themes";
  stateDir = "${homeDir}/.local/state/glow";

  defaultTheme = "retro-orange";
  defaultThemePath = "${themesDirOut}/${defaultTheme}.json";

  themeConfigs = builtins.listToAttrs (
    map (name: {
      name = "glow/themes/${name}.json";
      value.source = "${themesDir}/${name}.json";
    }) themeNames
  );
in
{
  # Deploy every theme, the default config, and the picker's theme list.
  xdg.configFile = themeConfigs // {
    "glow/glow.yml" = {
      force = true;
      text = ''
        # Managed by Home Manager (modules/glow.nix). Do not edit by hand.
        # Default theme. Use the `glow-set-theme` fish function to switch: it
        # writes a runtime override to $GLOW_CONFIG_HOME (${stateDir}).
        style: "${defaultThemePath}"
        mouse: false
        pager: false
        width: 80
        all: false
      '';
    };

    "glow/themes.list".text = concatStringsSep "\n" themeNames + "\n";

    # Set GLOW_CONFIG_HOME in every fish shell. conf.d runs before config.fish
    # and is unaffected by home-manager's session-vars guard, so child shells
    # spawned from an old session still pick up the runtime theme override.
    "fish/conf.d/glow.fish".text = ''
      set -gx GLOW_CONFIG_HOME "$HOME/.local/state/glow"
    '';
  };

  # glow reads this directory before ~/.config/glow, so the runtime override
  # written by `glow-set-theme` wins without touching the managed config.
  home.sessionVariables.GLOW_CONFIG_HOME = stateDir;

  programs.fish.functions."glow-set-theme" = {
    description = "Pick the glow markdown theme (persisted via GLOW_CONFIG_HOME)";
    body = ''
      set -l config_dir "$HOME/.config/glow"
      set -l themes_dir "$config_dir/themes"
      set -l state_dir "$HOME/.local/state/glow"
      set -l list_file "$config_dir/themes.list"

      if test "$argv[1]" = "--reset"
          rm -f "$state_dir/glow.yml"
          set -e GLAMOUR_STYLE
          echo "glow theme override cleared (default: ${defaultTheme})"
          return 0
      end

      set -l names
      if test -f "$list_file"
          set names (string split -n "\n" < "$list_file")
      else
          set names (for f in "$themes_dir"/*.json
              basename "$f" .json
          end)
      end

      if test (count $names) -eq 0
          echo "glow-set-theme: no themes found in $themes_dir" >&2
          return 1
      end

      set -l chosen
      if test (count $argv) -ge 1
          if not contains -- "$argv[1]" $names
              echo "glow-set-theme: unknown theme '$argv[1]'" >&2
              echo "available: $names" >&2
              return 1
          end
          set chosen "$argv[1]"
      else
          set chosen (printf '%s\n' $names | fzf --height 40% --reverse --prompt 'glow theme> ')
          or return 0
      end

      mkdir -p "$state_dir"
      if test -f "$config_dir/glow.yml"
          sed "s|^style:.*|style: \"$themes_dir/$chosen.json\"|" "$config_dir/glow.yml" > "$state_dir/glow.yml"
      else
          printf 'style: "%s"\n' "$themes_dir/$chosen.json" > "$state_dir/glow.yml"
      end
      set -Ux GLAMOUR_STYLE "$themes_dir/$chosen.json"
      echo "glow theme set to: $chosen"
    '';
  };
}
