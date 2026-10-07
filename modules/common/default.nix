{ ... }:

# Cross-platform modules: these build on every supported platform.
# Add a package that works everywhere to packages.nix and it is included
# for Linux and macOS alike. One concern per file.
{
  imports = [
    ./core.nix
    ./env.nix
    ./fish.nix
    ./packages.nix
    ./opencode.nix
    ./gmail-mcp.nix
    ./firecrawl.nix
    ./obsidian.nix
    ./glow.nix
    ./epub.nix
    ./immich.nix
    ./filebrowser.nix
    ./mangal.nix
  ];
}
