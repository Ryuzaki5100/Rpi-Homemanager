#!/usr/bin/env bash
set -euo pipefail

# One-time Tailscale setup: run the daemon under systemd, authenticate, and
# keep it running across reboots.
#
# Home Manager only manages *user* systemd units, but tailscaled must run as
# root (it creates the TUN device and owns /var/run/tailscale), so this script
# installs a system unit. It is idempotent and safe to re-run: any stray,
# manually-started tailscaled is stopped first so the systemd unit can own the
# control socket.

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root. This script uses sudo when needed."
    exit 1
fi

TAILSCALE="$(command -v tailscale || true)"
TAILSCALED="$(command -v tailscaled || true)"

if [ -z "$TAILSCALE" ] || [ -z "$TAILSCALED" ]; then
    echo "tailscale/tailscaled not found in PATH. Run 'home-manager switch' first."
    exit 1
fi

UNIT="/etc/systemd/system/tailscaled.service"

# The nix `tailscaled` is a wrapper script: the running process's name is
# ".tailscaled-wrapped" (truncated to ".tailscaled-wra"), so `pgrep -x tailscaled`
# never matches it. Match the command line instead. The pattern is deliberately
# narrow so it cannot match this script's own command line.
tailscaled_pids() {
    pgrep -f 'bin/tailscaled( |$)' 2>/dev/null || true
}

echo "==> Writing systemd unit ($UNIT)..."
sudo tee "$UNIT" >/dev/null <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
After=network-pre.target network-online.target
Wants=network-online.target

[Service]
User=root
ExecStart=$TAILSCALED
Restart=on-failure
RestartSec=5
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

echo "==> Stopping any stray tailscaled so systemd can own the socket..."
if [ -n "$(tailscaled_pids)" ]; then
    sudo pkill -f 'bin/tailscaled( |$)' 2>/dev/null || true
    for _ in $(seq 1 50); do
        [ -z "$(tailscaled_pids)" ] && break
        sleep 0.1
    done
    if [ -n "$(tailscaled_pids)" ]; then
        echo "    Still alive; sending SIGKILL..."
        sudo pkill -9 -f 'bin/tailscaled( |$)' 2>/dev/null || true
        sleep 0.5
    fi
fi

echo "==> Enabling and (re)starting tailscaled.service..."
sudo systemctl daemon-reload
sudo systemctl enable tailscaled >/dev/null
sudo systemctl restart tailscaled

echo "==> Waiting for the daemon..."
for _ in $(seq 1 50); do
    [ -S /var/run/tailscale/tailscaled.sock ] && break
    sleep 0.2
done
if [ ! -S /var/run/tailscale/tailscaled.sock ]; then
    echo "tailscaled did not come up. Recent logs:"
    sudo journalctl -u tailscaled -n 30 --no-pager || true
    exit 1
fi

if "$TAILSCALE" status --json 2>/dev/null | grep -q '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    echo "==> Already connected; skipping 'tailscale up'."
else
    echo "==> Starting Tailscale login (open the URL it prints)..."
    sudo env "PATH=$PATH" "$TAILSCALE" up
fi

echo ""
echo "==> Tailscale status:"
"$TAILSCALE" status

echo "==> Waiting for the tailnet interface..."
for _ in $(seq 1 50); do
    ip -4 addr show tailscale0 2>/dev/null | grep -q 'inet 100\.' && break
    sleep 0.2
done
if ! ip -4 addr show tailscale0 2>/dev/null | grep -q 'inet 100\.'; then
    echo "WARNING: tailscale0 has no tailnet IPv4 yet. Interface state:"
    ip addr show tailscale0 2>/dev/null || true
    echo "    Check: sudo journalctl -u tailscaled -n 50 --no-pager"
fi

if "$TAILSCALE" status --json | grep -q '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    echo ""
    echo "==> Tailscale is active. tailscaled.service is enabled for boot."
else
    echo ""
    echo "Tailscale is not yet connected. Run the script again after authenticating."
    exit 1
fi

echo "Defaults secure_path=\"$(dirname "$TAILSCALE"):/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" | sudo tee /etc/sudoers.d/nix-path >/dev/null
