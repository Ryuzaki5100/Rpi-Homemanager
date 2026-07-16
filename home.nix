{ obsitui, nixvim-editor, ... }: {

  imports = [
    ./modules/core.nix
    ./modules/env.nix
    ./modules/fish.nix
    ./modules/packages.nix
    ./modules/obsidian.nix
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "openclaw-2026.6.11"
  ];

  xdg.configFile."mangal/mangal.toml".text = ''
    [downloader]
    path = "/home/ryuzaki/manga"
    create_manga_dir = true

    [formats]
    use = "pdf"

    [mangadex]
    language = "en"
    nsfw = false
  '';
}
