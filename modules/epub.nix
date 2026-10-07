{
  pkgs,
  ...
}:

{
  # Tooling for building EPUB books from the ~/interview-prep markdown tree.
  # Everything is declared here (no manual installs): pandoc is already in
  # modules/packages.nix; this module adds the validator, the font used for
  # monospace code and ASCII/box-drawing diagrams, and the interpreter used by
  # the preprocessing step.
  home.packages = with pkgs; [
    epubcheck
    dejavu_fonts
    python3
  ];
}
