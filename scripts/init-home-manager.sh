#!/usr/bin/env bash

set -euo pipefail

# Run from this script's repo root so `--flake .#...` resolves to the flake and
# not to the caller's current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

if ! command -v nix >/dev/null 2>&1; then
    echo "ERROR: nix is not on PATH. Install it first: $REPO_DIR/scripts/install-nix.sh" >&2
    exit 1
fi

# Some distro packages (e.g. Arch's `nix`) ship the binaries and the daemon but
# never run `nix-store --init`, so the first Nix command fails with:
#   error: opening file "/nix/store": No such file or directory
# Initialize the store before doing anything else.
if [ ! -d /nix/store ]; then
    echo "==> Nix store is missing; initializing /nix/store..."
    if ! nix-store --init 2>/dev/null; then
        sudo nix-store --init
    fi
fi

echo "==> Enabling flakes in /etc/nix/nix.conf..."

sudo mkdir -p /etc/nix
if ! grep -q "^experimental-features = .*nix-command.*flakes" /etc/nix/nix.conf 2>/dev/null; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
fi

echo "==> Applying Home Manager configuration from $REPO_DIR..."
# --impure lets the flake auto-detect the host architecture (aarch64/x86_64)
# and the invoking user.
nix run github:nix-community/home-manager -- switch --flake ".#$(whoami)" --impure

FISH_PATH="$(command -v fish)"

echo "==> Adding Fish to /etc/shells..."
if ! grep -qx "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

echo "==> Changing default shell to Fish..."
chsh -s "$FISH_PATH"

echo "==> Rebooting..."
sudo reboot
