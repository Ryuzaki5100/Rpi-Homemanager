{ ... }:

# macOS layer (Apple Silicon).
{
  imports = [
    ./packages.nix
    ./filebrowser.nix
    ./ghostty.nix
  ];

  # The App Management pre-check touches every managed .app bundle, which
  # requires interactive TCC approval and aborts activation when it is missing.
  # Our app bundles are immutable nix store paths (rsync only rewrites real
  # changes), so skip the check.
  targets.darwin.copyApps.enableChecks = false;
}
