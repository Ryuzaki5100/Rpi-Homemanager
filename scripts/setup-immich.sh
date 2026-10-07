#!/usr/bin/env bash
set -euo pipefail

# Immich setup. Ensures the Docker daemon is running (the CLI comes from
# nixpkgs via Home Manager), then pulls and starts the compose stack.
#
#   Linux  -> systemd-managed docker, run through `sg docker`
#   macOS  -> Docker Desktop (launched if needed), plain `docker`

IMMICH_DIR="$HOME/.config/immich"

if [ "$(uname -s)" = "Darwin" ]; then
    echo "==> macOS detected: using Docker Desktop."
    if ! docker info &>/dev/null; then
        echo "==> Starting Docker Desktop..."
        open -a Docker || true
        echo "==> Waiting for the Docker daemon..."
        for _ in $(seq 1 60); do
            docker info &>/dev/null && break
            sleep 2
        done
    fi
    docker info &>/dev/null || {
        echo "ERROR: Docker daemon not reachable. Install/start Docker Desktop." >&2
        exit 1
    }
    DOCKER=(docker)
else
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
    DOCKER=(sg docker -c)
fi

echo "==> Creating Immich directories..."
mkdir -p "$HOME/immich/library"
mkdir -p "$HOME/immich/postgres"

echo "==> Pulling latest images..."
cd "$IMMICH_DIR"
if [ "${DOCKER[0]}" = "sg" ]; then
    sg docker -c "docker compose pull"
    echo "==> Starting Immich..."
    sg docker -c "docker compose up -d"
else
    docker compose pull
    echo "==> Starting Immich..."
    docker compose up -d
fi

echo ""
echo "==> Immich is starting up!"
echo "    First run will take a few minutes to initialize the database."
if [ "$(uname -s)" = "Darwin" ]; then
    IP="localhost"
else
    IP=$(hostname -I | awk '{print $1}')
fi
echo "    Access it at: http://${IP}:2283"
