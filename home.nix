{
  config,
  lib,
  obsitui,
  nixvim-editor,
  ...
}:
{

  imports = [
    ./modules/host.nix
    ./modules/core.nix
    ./modules/env.nix
    ./modules/fish.nix
    ./modules/packages.nix
    ./modules/mpv.nix
    ./modules/obsidian.nix
    ./modules/opencode.nix
    ./modules/gmail-mcp.nix
    ./modules/firecrawl.nix
    ./modules/immich.nix
    ./modules/filebrowser.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "openclaw-2026.6.11"
    ];
  };

  # The /mnt/hdd mount is Raspberry Pi storage; skip the convenience symlink on
  # x86 hosts where it would just dangle.
  home.activation.createMountLinks = lib.mkIf config.host.isRpi ''
    ln -sfn /mnt/hdd ~/hdd
  '';

  services.filebrowser = {
    enable = true;
  };

  xdg.configFile."mangal/mangal.toml".text = ''
    [downloader]
    path = "${config.home.homeDirectory}/manga"
    create_manga_dir = true

    [formats]
    use = "pdf"

    [mangadex]
    language = "en"
    nsfw = false
  '';


}
