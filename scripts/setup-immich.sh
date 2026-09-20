#!/usr/bin/env bash
set -euo pipefail

# Immich setup bootstrap (any Linux: Raspberry Pi OS/Debian, Arch, Fedora)
# Ensures the Docker daemon is running (the CLI comes from nixpkgs via Home
# Manager). The compose file itself is architecture-aware; see modules/immich.nix.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

IMMICH_DIR="$HOME/.config/immich"

echo "==> Checking for Docker daemon..."
if ! docker info &>/dev/null; then
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "==> Docker daemon is running but current user lacks access."
        echo "==> Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        echo "==> Run: sg docker -c '$0' or log out and back in."
        exit 1
    elif systemctl list-unit-files docker.service 2>/dev/null | grep -q '^docker\.service'; then
        echo "==> Starting Docker daemon..."
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "ERROR: the Docker daemon (docker.service) is not installed."
        echo "       Home Manager provides only the docker CLI; install the daemon"
        echo "       with your distro package manager, e.g.:"
        echo "         Debian/RPi OS: sudo apt-get install -y docker.io"
        echo "         Arch:          sudo pacman -S docker && sudo systemctl enable --now docker"
        echo "         Fedora:        sudo dnf install -y moby-engine && sudo systemctl enable --now docker"
        exit 1
    fi
fi

echo "==> Creating Immich directories..."
mkdir -p "$HOME/immich/library"
mkdir -p "$HOME/immich/postgres"

echo "==> Pulling latest images..."
cd "$IMMICH_DIR"
sg docker -c "docker compose pull"

echo "==> Starting Immich..."
sg docker -c "docker compose up -d"

echo ""
echo "==> Immich is starting up!"
echo "    First run will take a few minutes to initialize the database."
IP="$(host_ip)"
echo "    Access it at: http://${IP}:2283"
echo ""
echo "    Quick commands:  make -C ~/dotfiles immich-status"
echo "                     make -C ~/dotfiles immich-logs"
