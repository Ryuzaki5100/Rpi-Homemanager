{
  pkgs,
  ...
}:

{
  # Tooling for building EPUB books from the ~/interview-prep markdown tree.
  # Everything is declared here (no manual installs): pandoc is already in
  # modules/common/packages.nix; this module adds the validator, the font used
  # for monospace code and ASCII/box-drawing diagrams, the interpreter used by
  # the preprocessing step, and fontconfig (so build-epubs.sh's fc-match works
  # on macOS as well as Linux).
  home.packages = with pkgs; [
    epubcheck
    dejavu_fonts
    fontconfig
    python3
  ];
}
