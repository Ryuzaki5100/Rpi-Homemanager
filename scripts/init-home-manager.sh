#!/usr/bin/env bash

set -euo pipefail

# Bootstrap Home Manager (standalone) on a fresh machine and set Fish as the
# login shell. Linux enables flakes in /etc/nix/nix.conf; macOS relies on the
# Determinate installer's defaults (install Nix first with scripts/install-nix.sh).

OS="$(uname -s)"

if [ "$OS" != "Darwin" ]; then
    echo "==> Enabling flakes in /etc/nix/nix.conf..."
    if ! grep -q "^experimental-features = .*nix-command.*flakes" /etc/nix/nix.conf 2>/dev/null; then
        echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
    fi
fi

echo "==> Applying Home Manager configuration..."
# --impure lets the flake read the host system/username (builtins.currentSystem
# / builtins.getEnv) so the same command targets Linux or macOS correctly.
nix run github:nix-community/home-manager -- switch --impure --flake .#$(whoami)

FISH_PATH="$(command -v fish)"

echo "==> Adding Fish to /etc/shells..."
if ! grep -qx "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

echo "==> Changing default shell to Fish..."
chsh -s "$FISH_PATH"

if [ "$OS" = "Darwin" ]; then
    echo "==> Done. macOS does not need a reboot; open a new terminal to use Fish."
else
    echo "==> Rebooting..."
    sudo reboot
fi
