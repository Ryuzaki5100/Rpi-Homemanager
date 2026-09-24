{
  pkgs,
  config,
  obsitui,
  nixvim-editor,
  ...
}:

let
  inherit (pkgs) lib;

  # Nix-built mpv on a non-NixOS host (Omarchy/Arch) cannot find the host GL
  # drivers, so every EGL/Vulkan GPU context fails to initialise and mpv's
  # context probing aborts on `assert(!vo->x11)` (upstream mpv #17190, fixed
  # post-0.41.0 by #17191). Wrapping with nixGL points mpv at a matching Mesa
  # stack so the Wayland/EGL context succeeds and hardware acceleration works.
  # The mpv.conf fallback in modules/mpv.nix catches the case where it doesn't.
  mpv' =
    if config.host.isX86 then
      pkgs.symlinkJoin {
        name = "mpv-nixgl-${pkgs.mpv.version}";
        paths = [ pkgs.mpv ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          mv $out/bin/mpv $out/bin/.mpv-unwrapped
          makeWrapper ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL $out/bin/mpv \
            --add-flags $out/bin/.mpv-unwrapped
        '';
      }
    else
      pkgs.mpv;

  # Packages that build and run on every supported architecture.
  common = with pkgs; [
    # Editors
    neovim
    code-server
    opencode

    # Dev tools
    lazygit
    tmux

    # Containers
    docker
    docker-compose
    jq

    # System info
    fastfetch
    hyfetch
    nitch
    btop
    clock-rs
    smartmontools
    exfatprogs

    # Media & graphics
    chafa
    timg
    mpv'
    ffmpeg
    yt-dlp
    yazi
    pandoc

    # Networking & chat
    browsh
    nchat
    bluetuith
    wifitui
    tailscale
    reddit-tui
    reddix
    discordo
    wiki-tui
    hackernews-tui
    youtube-tui
    smassh
    gemini-cli
    mangal
    # ani-cli
    # nyaa

    # Obsidian TUIs
    basalt
    obsitui
    nixvim-editor

    # Flashcards (SM-2 spaced repetition TUI)
    # srl-tui

    # Fun
    cmatrix
    posting

    # Automation tools
    # openclaw
  ];

  # x86_64-only extras. `localsend` pulls in Flutter's `aapt`, which has no
  # aarch64-linux build, so it is only available on x86.
  x86Only = with pkgs; [
    localsend
  ];
in
{
  home.packages =
    common
    ++ lib.optionals config.host.isX86 x86Only;
}
