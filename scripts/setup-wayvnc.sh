#!/usr/bin/env bash
set -euo pipefail

RES_WIDTH=2388
RES_HEIGHT=1668
REFRESH=60
VNC_PASSWD=""
VNC_SERVICE_FILE="/etc/systemd/system/wayvnc-session.service"

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root. This script uses sudo when needed."
    exit 1
fi

echo "==> Disabling RealVNC (if present)..."
if systemctl is-enabled vncserver-x11-serviced &>/dev/null; then
    sudo systemctl stop vncserver-x11-serviced 2>/dev/null || true
    sudo systemctl disable vncserver-x11-serviced 2>/dev/null || true
    echo "    RealVNC stopped and disabled."
else
    echo "    Not found or already disabled, skipping."
fi

echo "==> Setting VNC password..."
while true; do
    read -rsp "    Enter VNC password: " pw1
    echo
    read -rsp "    Confirm VNC password: " pw2
    echo
    if [ "$pw1" != "$pw2" ]; then
        echo "    Passwords do not match. Try again."
    elif [ ${#pw1} -lt 4 ]; then
        echo "    Password must be at least 4 characters. Try again."
    else
        VNC_PASSWD="$pw1"
        break
    fi
done

echo "==> Creating wayvnc config..."
mkdir -p "$HOME/.config/wayvnc"

OUTPUT_NAME=$(sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$(id -u)" WAYLAND_DISPLAY=wayland-0 wlr-randr 2>/dev/null | head -1 | awk '{print $1}')
if [ -z "$OUTPUT_NAME" ]; then
    echo "    Warning: Could not detect Wayland output name. Using 'NOOP-1'."
    OUTPUT_NAME="NOOP-1"
fi

cat > "$HOME/.config/wayvnc/config" << CONFIGEOF
address=0.0.0.0
enable_auth=true
username=$USER
password=$VNC_PASSWD
enable_pam=false
private_key_file=/etc/wayvnc/tls_key.pem
certificate_file=/etc/wayvnc/tls_cert.pem
rsa_private_key_file=/etc/wayvnc/rsa_key.pem
use_relative_paths=false
CONFIGEOF
echo "    Config written to $HOME/.config/wayvnc/config"

echo "==> Generating TLS/RSA keys..."
if [ ! -f /etc/wayvnc/rsa_key.pem ] || [ ! -f /etc/wayvnc/tls_key.pem ]; then
    sudo /usr/sbin/wayvnc-generate-keys.sh
    sudo chmod 644 /etc/wayvnc/*.pem
    echo "    Keys generated."
else
    echo "    Keys already exist, skipping."
fi

echo "==> Creating systemd service..."
if [ -f "$VNC_SERVICE_FILE" ]; then
    echo "    Service file already exists, overwriting..."
fi

sudo tee "$VNC_SERVICE_FILE" > /dev/null << SERVICEEOF
[Unit]
Description=WayVNC (user session)
Documentation=man:wayvnc
After=network.target

[Service]
Type=simple
User=$USER
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
Environment=WAYLAND_DISPLAY=wayland-0
ExecStartPre=/bin/sh -c 'i=0; while [ ! -S /run/user/$(id -u)/wayland-0 ] && [ \$i -lt 30 ]; do sleep 1; i=\$((i+1)); done; [ -S /run/user/$(id -u)/wayland-0 ]'
ExecStartPre=/usr/bin/wlr-randr --output $OUTPUT_NAME --custom-mode ${RES_WIDTH}x${RES_HEIGHT}@${REFRESH}
ExecStart=/usr/bin/wayvnc --gpu --config $HOME/.config/wayvnc/config
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
SERVICEEOF
echo "    Service written to $VNC_SERVICE_FILE"

echo "==> Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable --now wayvnc-session

echo ""
echo "============================================"
echo "  WayVNC setup complete!"
echo "  Resolution: ${RES_WIDTH}x${RES_HEIGHT} @ ${REFRESH}Hz"
echo "  Connect from iPad RealVNC Viewer:"
echo "    Address:  $(hostname -I | awk '{print $1}'):5900"
echo "    Username: $USER"
echo "    Password: (the one you entered)"
echo "============================================"
