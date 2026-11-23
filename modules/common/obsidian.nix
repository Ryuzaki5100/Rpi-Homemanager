{ config, pkgs, ... }:

let
  vaults = {
    personal = {
      uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
      path = "${config.home.homeDirectory}/notes";
    };

    # Game-project memory + task queue for the noclip agent workflow
    # (modules/darwin/roblox-agents.nix). `noclip init` fills it; this only
    # registers it so Obsidian/basalt can open it.
    noclip = {
      uuid = "7f2c9b1e-4d38-4a6f-9c05-b8e1d2a34f61";
      path = "${config.home.homeDirectory}/roblox/noclip-protocol-vault";
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
