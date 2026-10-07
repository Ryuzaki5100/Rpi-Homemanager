{
  pkgs,
  obsitui,
  nixvim-editor,
  ...
}:

let
  inherit (pkgs) lib;
in
{

  home.packages = with pkgs; [
    # Editors
    neovim
    code-server
    opencode

    # Dev tools
    lazygit
    tmux
    zellij
    fzf
    jdk
    maven

    # Containers
    docker
    docker-compose
    jq

    # System info
    fastfetch
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
    dysk
    foliate
    nix-search-tv
    # localsend

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
    glow
    nixvim-editor

    # Flashcards (SM-2 spaced repetition TUI)
    # srl-tui

    # Fun
    cmatrix
    posting
    asciiquarium

    # Automation tools
    # openclaw
  ];
}
