#!/usr/bin/env bash

set -euo pipefail

echo "==> Enabling flakes in /etc/nix/nix.conf..."

if ! grep -q "^experimental-features = .*nix-command.*flakes" /etc/nix/nix.conf 2>/dev/null; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
fi

echo "==> Applying Home Manager configuration..."
nix run github:nix-community/home-manager -- switch --flake .#ryuzaki

FISH_PATH="$(command -v fish)"

echo "==> Adding Fish to /etc/shells..."
if ! grep -qx "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

echo "==> Changing default shell to Fish..."
chsh -s "$FISH_PATH"

echo "==> Rebooting..."
sudo reboot
