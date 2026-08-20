{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Resolve the invoking user dynamically (whoami at eval time) so the
      # same flake works on any machine/OS with a working Nix+flakes setup.
      # Falls back to the historic default when USER is unset (e.g. cron, sudo).
      currentUser = builtins.getEnv "USER";
      userName = if currentUser == "" then "ryuzaki" else currentUser;

      obsitui = pkgs.callPackage ./pkgs/obsitui.nix { };
      nixvim-editor = pkgs.callPackage ./pkgs/nixvim-editor.nix { };
      srl-tui = pkgs.callPackage ./pkgs/srl-tui.nix { };
      gmail-mcp-auth = pkgs.callPackage ./pkgs/gmail-mcp-auth.nix { };

      pkgs' = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            srl-tui = prev.callPackage ./pkgs/srl-tui.nix { };
            gmail-mcp-auth = prev.callPackage ./pkgs/gmail-mcp-auth.nix { };
          })
        ];
      };
    in
    {
      packages.${system} = {
        inherit obsitui nixvim-editor srl-tui gmail-mcp-auth;
      };

      homeConfigurations.${userName} = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs';
        modules = [
          ./home.nix
        ];
        extraSpecialArgs = { inherit obsitui nixvim-editor; };
      };
    };
}
