{ ... }:

# Linux-only activation: expose the external HDD at ~/hdd. macOS has no
# /mnt/hdd; external volumes live under /Volumes and need no symlink.
{
  home.activation.createMountLinks = ''
    ln -sfn /mnt/hdd ~/hdd
  '';
}
