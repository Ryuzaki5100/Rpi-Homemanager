#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root."
    exit 1
fi

OPENCODE_PORT="${OPENCODE_PORT:-4096}"

if ! command -v opencode &>/dev/null; then
    echo "opencode not found in PATH."
    exit 1
fi

OPENCODE_PID=""
cleanup() {
    echo ""
    echo "==> Shutting down..."
    [ -n "$OPENCODE_PID" ] && kill "$OPENCODE_PID" 2>/dev/null || true
    if command -v tailscale &>/dev/null; then
        echo "==> Removing tailscale serve config..."
        sudo tailscale serve reset 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

if lsof -ti:"${OPENCODE_PORT}" &>/dev/null; then
    echo "==> Port ${OPENCODE_PORT} in use; killing old process..."
    lsof -ti:"${OPENCODE_PORT}" | xargs kill 2>/dev/null || true
    sleep 1
fi

echo "==> Starting opencode serve on 0.0.0.0:${OPENCODE_PORT}..."
opencode serve --hostname 0.0.0.0 --port "$OPENCODE_PORT" &
OPENCODE_PID=$!

for i in $(seq 1 10); do
    if curl -sf "http://127.0.0.1:${OPENCODE_PORT}/global/health" &>/dev/null; then
        break
    fi
    sleep 1
done

echo "==> Exposing on tailnet via tailscale serve..."
if sudo tailscale serve --bg "http://127.0.0.1:${OPENCODE_PORT}" 2>/dev/null; then
    echo "==> opencode serve is live on your tailnet at port ${OPENCODE_PORT}"
else
    echo "==> tailscale serve not available; server is accessible on 0.0.0.0:${OPENCODE_PORT}"
fi

echo "==> Waiting for opencode serve (PID ${OPENCODE_PID})..."
wait "$OPENCODE_PID"
