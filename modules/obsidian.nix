{ config, pkgs, ... }:

let
  vaults = {
    personal = {
      uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
      path = "${config.home.homeDirectory}/notes";
    };
  };
in {

  # Obsidian vault discovery (used by basalt)
  xdg.configFile."obsidian/obsidian.json".text = builtins.toJSON {
    vaults = builtins.mapAttrs (_: v: { path = v.path; }) vaults;
  };

  # Ensure vault directories exist
  home.file = builtins.listToAttrs (builtins.map (v:
    let rel = builtins.replaceStrings [ "${config.home.homeDirectory}/" ] [ "" ] v.path;
    in { name = "${rel}/.keep"; value = { text = ""; }; }
  ) (builtins.attrValues vaults));

  # Basalt config
  xdg.configFile."basalt/config.toml".text = ''
    vim_mode = true
    experimental_editor = true

    [global]
    key_bindings = [
      { key = "ctrl+e", command = "exec:nix run github:Ryuzaki5100/nixvim --refresh -- %note_path" },
      { key = "ctrl+alt+e", command = "spawn:nix run github:Ryuzaki5100/nixvim --refresh -- %note_path" },
    ]
  '';
}
