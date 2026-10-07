{ ... }:

# Top-level Home Manager module. All logic lives in modules/ (layered by
# platform); this file only wires the tree in and sets shared nixpkgs config.
{
  imports = [ ./modules ];

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "openclaw-2026.6.11"
    ];
  };
}
