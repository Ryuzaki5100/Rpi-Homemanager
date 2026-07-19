#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root. This script uses sudo when needed."
    exit 1
fi

TAILSCALE="$(command -v tailscale)"

if [ -z "$TAILSCALE" ]; then
    echo "tailscale not found in PATH. Run 'home-manager switch' first."
    exit 1
fi

TAILSCALED="$(dirname "$TAILSCALE")/tailscaled"

echo "==> Starting tailscaled daemon..."
if ! pgrep -x tailscaled &>/dev/null; then
    sudo env "PATH=$PATH" "$TAILSCALED" &>/dev/null &
    sleep 2
fi

echo "==> Starting Tailscale login..."
sudo env "PATH=$PATH" "$TAILSCALE" up

echo ""
echo "==> Tailscale status:"
"$TAILSCALE" status

if "$TAILSCALE" status --json | grep -q '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    echo ""
    echo "==> Tailscale is active. Enabling systemd service for auto-start on boot..."
    if systemctl list-unit-files tailscaled.service &>/dev/null; then
        sudo systemctl enable tailscaled
    else
        echo "    systemd unit not found — creating one..."
        sudo tee /etc/systemd/system/tailscaled.service >/dev/null <<EOF
[Unit]
Description=Tailscale node agent
After=network-pre.target network-online.target
Wants=network-online.target

[Service]
User=root
ExecStart=$TAILSCALED
ExecStopPost=/bin/sh -c '/bin/kill \$MAINPID 2>/dev/null; while pgrep -x tailscaled >/dev/null; do sleep 0.1; done'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable --now tailscaled
    fi
    echo ""
    echo "Done! Tailscale will start automatically on boot."
else
    echo ""
    echo "Tailscale is not yet connected. Run the script again after authenticating."
    exit 1
fi

echo 'Defaults secure_path="/home/ryuzaki/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' | sudo tee /etc/sudoers.d/nix-path
