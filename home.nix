{ obsitui, nixvim-editor, ... }: {

  imports = [
    ./modules/core.nix
    ./modules/env.nix
    ./modules/fish.nix
    ./modules/packages.nix
    ./modules/obsidian.nix
  ];
}
