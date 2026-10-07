{ pkgs, ... }:

# macOS-only packages. Cross-platform tools live in modules/common/packages.nix;
# keep this list for things that build on (or are only wanted on) Apple Silicon.
{
  home.packages = with pkgs; [
    # Nothing macOS-specific yet. Examples that would go here: brew, mas, ...
  ];
}
