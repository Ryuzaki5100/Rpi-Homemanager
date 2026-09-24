{ config, lib, ... }:

{
  # Work around upstream mpv #17190. When a GPU context initialises the VO
  # backend but then fails (on a non-NixOS host the Nix mpv's Wayland/EGL
  # context does exactly this), the leftover backend pointer - `vo->x11` and
  # `vo->wl` share an anonymous union in `struct vo` - makes the next X11
  # context abort on `assert(!vo->x11)` instead of falling back.
  #
  # Pinning the OpenGL Wayland context stops mpv from ever reaching the X11
  # context. With the nixGL-wrapped mpv this context succeeds and uses the
  # GPU; without it mpv degrades to the software `wlshm` VO instead of
  # crashing. This assumes a Wayland session (Omarchy/Hyprland), which is the
  # x86 target.
  xdg.configFile."mpv/mpv.conf" = lib.mkIf config.host.isX86 {
    text = ''
      gpu-context=wayland
    '';
  };
}
