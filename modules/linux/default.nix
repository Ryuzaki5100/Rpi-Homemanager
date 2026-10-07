{ ... }:

# Linux layer: shared by x86_64-linux and aarch64-linux.
{
  imports = [
    ./packages.nix
    ./mounts.nix
    ./immich.nix
    ./filebrowser.nix
  ];
}
