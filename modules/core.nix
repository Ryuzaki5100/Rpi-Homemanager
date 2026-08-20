{ ... }:
let
  # Resolve the invoking user dynamically, mirroring the flake's own
  # homeConfigurations name. Works on NixOS, Debian, RPi OS, etc.
  currentUser = builtins.getEnv "USER";
  userName = if currentUser == "" then "ryuzaki" else currentUser;
in
{
  home.username = userName;
  home.homeDirectory = "/home/${userName}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
