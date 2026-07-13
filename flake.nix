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
    { nixpkgs, home-manager, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      obsitui = pkgs.callPackage ./pkgs/obsitui.nix { };
      nixvim-editor = pkgs.callPackage ./pkgs/nixvim-editor.nix { };
    in
    {
      packages.${system} = {
        inherit obsitui nixvim-editor;
      };

      homeConfigurations.ryuzaki = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = { inherit obsitui nixvim-editor; };
      };
    };
}
