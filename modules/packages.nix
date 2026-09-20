{
  pkgs,
  config,
  obsitui,
  nixvim-editor,
  ...
}:

let
  inherit (pkgs) lib;

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
    mpv
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
