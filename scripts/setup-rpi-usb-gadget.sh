#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root. This script uses sudo when needed."
    exit 1
fi

echo "==> Adding USB gadget kernel modules to cmdline.txt..."

CMDLINE=/boot/firmware/cmdline.txt
if ! grep -q "modules-load=dwc2,g_ether" "$CMDLINE" 2>/dev/null; then
    sudo sed -i 's/rootwait/rootwait modules-load=dwc2,g_ether/' "$CMDLINE"
else
    echo "    Already present, skipping."
fi

echo "==> Adding dwc2 overlay in config.txt..."

CONFIG=/boot/firmware/config.txt

if grep -q '^dtoverlay=dwc2' <(grep -A5 '^\[all\]' "$CONFIG") 2>/dev/null; then
    echo "    dtoverlay=dwc2 already present under [all], skipping."
else
    if grep -q '^\[all\]' "$CONFIG" 2>/dev/null; then
        sudo sed -i '/^\[all\]/a dtoverlay=dwc2' "$CONFIG"
    else
        printf '\n[all]\ndtoverlay=dwc2\n' | sudo tee -a "$CONFIG" >/dev/null
    fi
fi

echo "==> Creating ethernet-usb0 NetworkManager connection..."

if nmcli con show ethernet-usb0 &>/dev/null; then
    echo "    Connection already exists, skipping creation."
else
    sudo nmcli con add type ethernet con-name ethernet-usb0
fi

NMCONN=/etc/NetworkManager/system-connections/ethernet-usb0.nmconnection

echo "==> Configuring ethernet-usb0 connection settings..."

if [ -f "$NMCONN" ]; then
    sudo nmcli con mod ethernet-usb0 connection.autoconnect yes
    sudo nmcli con mod ethernet-usb0 connection.interface-name usb0
    sudo nmcli con mod ethernet-usb0 ipv4.method shared
else
    echo "    ERROR: $NMCONN not found. Aborting."
    exit 1
fi

echo "==> Creating USB gadget bringup script..."

GADGET_SCRIPT=/usr/local/sbin/usb-gadget.sh
printf '#!/bin/bash\n\nnmcli con up ethernet-usb0\n' | sudo tee "$GADGET_SCRIPT" >/dev/null
sudo chmod a+rx "$GADGET_SCRIPT"

echo "==> Creating systemd service..."

SERVICE_FILE=/lib/systemd/system/usbgadget.service
if [ -f "$SERVICE_FILE" ]; then
    echo "    Service file already exists, skipping."
else
    sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=My USB gadget
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/usb-gadget.sh

[Install]
WantedBy=sysinit.target
EOF
fi

echo "==> Enabling usbgadget.service..."
sudo systemctl enable usbgadget.service

echo ""
echo "Done! Reboot for changes to take effect."
