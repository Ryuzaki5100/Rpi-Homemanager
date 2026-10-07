#!/usr/bin/env bash
set -euo pipefail

# Install the multi-user (daemon) Nix package manager on Linux and macOS.
# The official installer supports multi-user on both; --daemon forces it
# (macOS has no single-user mode). Requires sudo.
echo "==> Installing Nix in multi-user mode (official installer)..."
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
