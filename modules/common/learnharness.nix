{ config, pkgs, ... }:

let
  dataDir = "${config.home.homeDirectory}/learning/learnharness-data";

  # The data repository is the single source of truth for learning records.
  # lh-sync is a plain shell helper so the app bundle, the Linux service and
  # the TUI all share one implementation.
  lhSync = pkgs.writeShellApplication {
    name = "lh-sync";
    runtimeInputs = with pkgs; [
      git
      curl
      coreutils
    ];
    text = builtins.readFile ./lh-sync.sh;
  };
in
{
  # `learnharness` (the server, and the .app bundle on macOS) and `lhtui`
  # (the terminal companion) come from the flake overlay.
  home.packages = [
    pkgs.learnharness
    pkgs.lhtui
    lhSync
  ];

  # Every tool — the app, the TUI, the learning-data skill readers — resolves
  # the same record. auth.json and provider keys stay outside this directory.
  home.sessionVariables.LH_DATA_DIR = dataDir;
}
