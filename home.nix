{
  obsitui,
  nixvim-editor,
  ...
}:
{

  imports = [
    ./modules/core.nix
    ./modules/env.nix
    ./modules/fish.nix
    ./modules/packages.nix
    ./modules/obsidian.nix
    ./modules/opencode.nix
    ./modules/gmail-mcp.nix
    ./modules/immich.nix
    ./modules/filebrowser.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "openclaw-2026.6.11"
    ];
  };

  home.activation.createMountLinks = ''
    ln -sfn /mnt/hdd ~/hdd
  '';

  services.filebrowser = {
    enable = true;
  };

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
