{ ... }:

# `pkgs.learnharness` (modules/common/learnharness.nix) ships
# Applications/LearnHarness.app. Home Manager's darwin copyApps target installs
# app bundles from home.packages into ~/Applications; the directory is pinned
# here so LearnHarness sits beside the other local apps instead of inside
# "Home Manager Apps".
{
  targets.darwin.copyApps.directory = "Applications";
}
