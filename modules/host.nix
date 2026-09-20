{ lib, pkgs, ... }:

# Central host-capability detection so every other module can branch on the
# architecture without repeating platform checks. `isRpi` is true on the
# aarch64 target (Raspberry Pi OS / NixOS on a Pi); `isX86` is true on
# x86_64 laptops and desktops. Both are read-only: they always reflect the
# machine Home Manager is currently evaluating on.
let
  hp = pkgs.stdenv.hostPlatform;

  isAarch64 = hp.isAarch64 or false;
  isX86 = hp.isx86_64 or false;
in
{
  options.host = {
    system = lib.mkOption {
      type = lib.types.str;
      default = hp.system;
      readOnly = true;
      description = "Nix system string, e.g. aarch64-linux or x86_64-linux.";
    };

    arch = lib.mkOption {
      type = lib.types.enum [ "aarch64" "x86_64" "other" ];
      default = if isAarch64 then "aarch64" else if isX86 then "x86_64" else "other";
      readOnly = true;
      description = "CPU architecture family of the current host.";
    };

    isRpi = lib.mkOption {
      type = lib.types.bool;
      default = isAarch64;
      readOnly = true;
      description = "True on aarch64-linux, the Raspberry Pi target.";
    };

    isX86 = lib.mkOption {
      type = lib.types.bool;
      default = isX86;
      readOnly = true;
      description = "True on x86_64-linux laptops and desktops.";
    };
  };
}
