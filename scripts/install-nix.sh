#!/usr/bin/env bash
set -euo pipefail

# Install Nix in multi-user (daemon) mode.
#   Linux  -> official nixos.org installer
#   macOS  -> Determinate Systems installer (the recommended macOS path)
case "$(uname -s)" in
Darwin)
    echo "==> macOS detected: installing Nix via the Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    ;;
*)
    echo "==> Linux detected: installing Nix via the official installer..."
    curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
    ;;
esac
