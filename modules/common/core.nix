{ pkgs, lib, ... }:
let
  # Resolve the invoking user dynamically, mirroring the flake's own
  # homeConfigurations name. Works on NixOS, Debian, RPi OS, macOS, etc.
  currentUser = builtins.getEnv "USER";
  userName = if currentUser == "" then "ryuzaki" else currentUser;

  # Prefer $HOME when set (correct on every platform); otherwise fall back to
  # the platform's conventional root: /Users on macOS, /home on Linux.
  envHome = builtins.getEnv "HOME";
  fallbackHome =
    if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${userName}" else "/home/${userName}";
in
{
  home.username = userName;
  home.homeDirectory = if envHome == "" then fallbackHome else envHome;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
