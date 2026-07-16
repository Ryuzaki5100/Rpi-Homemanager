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

    # System info
    fastfetch
    nitch
    btop
    clock-rs

    # Media & graphics
    chafa
    timg
    mpv
    ffmpeg
    yt-dlp
    yazi

    # Networking & chat
    browsh
    nchat
    bluetuith
    wifitui
    reddit-tui
    reddix
    smassh
    gemini-cli

    # Obsidian TUIs
    basalt
    obsitui
    nixvim-editor

    # Flashcards (SM-2 spaced repetition TUI)
    srl-tui

    # Fun
    cmatrix
  ];
}
