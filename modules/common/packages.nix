{
  pkgs,
  obsitui,
  nixvim-editor,
  ...
}:

# Cross-platform packages: every entry here is available on x86_64-linux,
# aarch64-linux and aarch64-darwin. Add a universally-compatible tool once
# and it lands on all platforms. Platform-specific tools live in
# modules/linux/packages.nix or modules/darwin/packages.nix.
{
  home.packages = with pkgs; [
    # Editors
    neovim
    opencode

    # Dev tools
    lazygit
    tmux
    zellij
    fzf
    jdk
    maven

    # Containers (CLI; the daemon is provided by the host / Docker Desktop)
    docker
    docker-compose
    jq

    # System info
    fastfetch
    btop
    clock-rs
    smartmontools

    # Media & graphics
    chafa
    timg
    mpv
    ffmpeg
    yt-dlp
    yazi
    pandoc
    dysk
    nix-search-tv
    # localsend

    # Networking & chat
    browsh
    nchat
    bitchat-cli
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
