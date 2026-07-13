{ config, pkgs, ... }: {

  # ── Basic Configuration ──────────────────────────────────────────────
  home.username = "ryuzaki";
  home.homeDirectory = "/home/ryuzaki";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── Shell: Fish ──────────────────────────────────────────────────────
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish

      bind ctrl-space accept-autosuggestion
      bind alt-space  accept-autosuggestion
      bind ₹          accept-autosuggestion
      bind shift-tab  accept-autosuggestion
    '';

    shellAliases = {
      nixvim               = "nix run github:Ryuzaki5100/nixvim --refresh";
      rebuild-home-manager = "home-manager switch --flake ~/dotfiles#ryuzaki";
      update-home-manager  = "cd ~/dotfiles && nix flake update && cd -";
      display              = "chafa -f kitty --fit-width";
    };
  };

  # ── Packages ─────────────────────────────────────────────────────────
  home.packages = with pkgs; [

    # Editors & Development
    neovim
    code-server
    opencode
    lazygit
    tmux

    # System info & monitoring
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
    reddit-tui
    smassh
    gemini-cli

    # Fun
    cmatrix

    # (spotify-player.override { withAudioBackend = "pulseaudio"; })
  ];
}
