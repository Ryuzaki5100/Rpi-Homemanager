#!/usr/bin/env bash
set -euo pipefail

# Install Nix in multi-user (daemon) mode. Architecture-agnostic: the official
# installer detects aarch64 vs x86_64 automatically.
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
