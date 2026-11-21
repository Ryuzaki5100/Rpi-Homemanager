{ ... }:

# `pkgs.learnharness` (modules/common/learnharness.nix) ships
# Applications/LearnHarness.app. Home Manager's darwin copyApps target copies
# app bundles from home.packages into ~/Applications, so no extra wiring is
# needed here; this module exists to keep the platform layer explicit.
{}
