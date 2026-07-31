#!/usr/bin/env bash
set -euo pipefail

# Immich setup script for Raspberry Pi (Debian)
# Ensures Docker daemon is running (CLI comes from nixpkgs via Home Manager)

IMMICH_DIR="$HOME/.config/immich"

echo "==> Checking for Docker daemon..."
if ! docker info &>/dev/null; then
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "==> Docker daemon is running but current user lacks access."
        echo "==> Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        echo "==> Run: sg docker -c '$0' or log out and back in."
        exit 1
    else
        echo "==> Starting Docker daemon..."
        sudo systemctl start docker
        sudo systemctl enable docker
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
IP=$(hostname -I | awk '{print $1}')
echo "    Access it at: http://${IP}:2283"
echo ""
echo "    Quick commands:  make -C ~/dotfiles status"
echo "                     make -C ~/dotfiles logs"
