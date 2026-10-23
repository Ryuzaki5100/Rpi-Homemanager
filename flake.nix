{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dripfetch = {
      url = "github:a-shygun/dripfetch?dir=packaging/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pebble = {
      url = "github:pebble-dev/pebble.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      dripfetch,
      pebble,
      ...
    }:
    let
      # Platforms we keep structurally in sync. x86_64-linux is supported by the
      # module tree but not currently exercised by a real machine.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Resolve the invoking user dynamically (whoami at eval time) so the
      # same flake works on any machine/OS with a working Nix+flakes setup.
      # Falls back to the historic default when USER is unset (e.g. cron, sudo,
      # or pure evaluation where getEnv returns "").
      currentUser = builtins.getEnv "USER";
      userName = if currentUser == "" then "ryuzaki" else currentUser;

      # Custom packages, exposed on the pinned nixpkgs through an overlay so
      # both `packages.<system>` and the Home Manager configuration see them.
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            (final: prev:
              let
                pebblePython = prev.python3.override {
                  packageOverrides = pyFinal: pyPrev: {
                    libpebble2 = pyFinal.callPackage "${pebble}/derivations/libpebble2.nix" { };
                    rsa = pyPrev.rsa.overrideAttrs (old: {
                      version = "4.9.1";
                      src = prev.fetchPypi {
                        pname = "rsa";
                        version = "4.9.1";
                        hash = "sha256-572/21SX2kwH39NVMOGpAmWdtv8kHjnZlTytBuvQrnU=";
                      };
                      doCheck = false;
                      dontCheck = true;
                      checkPhase = "true";
                      pytestCheckPhase = "true";
                    });
                  };
                };
                pypkjs = prev.callPackage ./pkgs/pypkjs.nix {
                  python3Packages = pebblePython.pkgs;
                };
              in
              {
                obsitui = prev.callPackage ./pkgs/obsitui.nix { };
                nixvim-editor = prev.callPackage ./pkgs/nixvim-editor.nix { };
                srl-tui = prev.callPackage ./pkgs/srl-tui.nix { };
                gmail-mcp-auth = prev.callPackage ./pkgs/gmail-mcp-auth.nix { };
                bitchat-cli = prev.callPackage ./pkgs/bitchat-cli.nix { };
                archify = prev.callPackage ./pkgs/archify.nix { };
                pebble-sdk = prev.callPackage ./pkgs/pebble-sdk { };
                inherit pypkjs;
                pebble-tool = prev.callPackage ./pkgs/pebble-tool.nix {
                  inherit pebble pypkjs;
                  python3Packages = pebblePython.pkgs;
                };
                # Patch upstream so Ctrl+C exits cleanly instead of dumping a
                # KeyboardInterrupt traceback (its run() loop only has a finally).
                dripfetch = dripfetch.packages.${system}.default.overrideAttrs (old: {
                  patches = (old.patches or [ ]) ++ [ ./pkgs/dripfetch-kbinterrupt.patch ];
                });
              })
          ];
        };

      # Home Manager config for the *current* host, so the same
      # `home-manager switch --impure --flake .#$(whoami)` works on Linux and
      # macOS. `builtins.currentSystem` is impure-only in modern Nix; under a
      # pure evaluation (e.g. `nix flake check`) we fall back to aarch64-linux.
      defaultSystem = "aarch64-linux";
      system = if builtins ? currentSystem then builtins.currentSystem else defaultSystem;
      pkgs = mkPkgs system;
    in
    {
      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs' = mkPkgs system;
        in
        {
          inherit (pkgs')
            obsitui
            nixvim-editor
            srl-tui
            gmail-mcp-auth
            bitchat-cli
            archify
            dripfetch
            pebble-sdk
            pebble-tool
            pypkjs
            ;
        }
      );

      homeConfigurations.${userName} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
        ];
        extraSpecialArgs = {
          # Pass pkgs as a special arg so the platform aggregator
          # (modules/default.nix) can branch on pkgs.stdenv.hostPlatform during
          # `imports` evaluation (module args from _module.args would recurse).
          inherit pkgs;
          inherit (pkgs) obsitui nixvim-editor;
          inherit pebble;
        };
      };
    };
}
