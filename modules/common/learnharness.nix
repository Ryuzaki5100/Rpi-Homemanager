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
  # The terminal companion and sync helper are shared; the LearnHarness app
  # itself is the official release on macOS and the packaged server on Linux
  # (modules/linux/learnharness.nix).
  home.packages = [
    pkgs.lhtui
    lhSync
  ];

  # Every tool — the app, the TUI, the learning-data skill readers — resolves
  # the same record. auth.json and provider keys stay outside this directory.
  home.sessionVariables.LH_DATA_DIR = dataDir;
}
