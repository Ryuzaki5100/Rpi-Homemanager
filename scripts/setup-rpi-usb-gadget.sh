#!/usr/bin/env bash
set -euo pipefail

# Configure a Raspberry Pi as a USB-Ethernet (CDC-ECM) gadget so an iPad,
# laptop, or other USB host can be tethered over the USB-C / OTG port.
#
# Preferred path: Raspberry Pi OS Trixie's built-in `rpi-usb-gadget` package
# (dwc2 overlay with dr_mode=peripheral, modules-load, NetworkManager
# client/shared profiles, IPv6 disabled, authoritative DHCP, ICS watcher).
#
# On top of that this script works around a known dwc2/iPadOS failure where
# host->device packets stop arriving (169.254 self-assigned IP) by installing
# a self-heal service that reloads g_ether, pins stable gadget MACs, and
# silences the Windows-only RNDIS login hint.
#
# Usage:
#   ./setup-rpi-usb-gadget.sh              # configure (preferred path)
#   sudo ./setup-rpi-usb-gadget.sh         # same, as root
#   ./setup-rpi-usb-gadget.sh --legacy     # force the old manual g_ether setup
#   ./setup-rpi-usb-gadget.sh --status     # show current gadget state
#   ./setup-rpi-usb-gadget.sh --reboot     # reboot automatically when done
#
# Safe to re-run: legacy config is cleaned up, the supported stack is
# idempotent, and the helper units are rewritten each time.

if [ "$(uname -s)" != "Linux" ]; then
    echo "This script is Linux/Raspberry Pi-only (USB gadget + NetworkManager)." >&2
    exit 0
fi

if ! [ -r /proc/device-tree/model ] || ! grep -q 'Raspberry Pi' /proc/device-tree/model 2>/dev/null; then
    echo "This script must run on a Raspberry Pi." >&2
    exit 1
fi

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

CMDLINE=/boot/firmware/cmdline.txt
CONFIG=/boot/firmware/config.txt
[ -f "$CMDLINE" ] || CMDLINE=/boot/cmdline.txt
[ -f "$CONFIG" ] || CONFIG=/boot/config.txt

LEGACY_PROFILE=ethernet-usb0
LEGACY_UNIT=/etc/systemd/system/usbgadget.service
LEGACY_UNIT_LIB=/lib/systemd/system/usbgadget.service
LEGACY_BRINGUP=/usr/local/sbin/usb-gadget.sh
OLD_RENOTIFY_SCRIPT=/usr/local/sbin/usb-gadget-renotify.sh
OLD_RENOTIFY_UNIT=/etc/systemd/system/usb-gadget-renotify.service
SELFHEAL_SCRIPT=/usr/local/sbin/usb-gadget-selfheal.sh
SELFHEAL_UNIT=/etc/systemd/system/usb-gadget-selfheal.service
MAC_CONF=/etc/modprobe.d/99-g_ether-gadget-macs.conf
DNSMASQ_SNIPPET=/etc/NetworkManager/dnsmasq-shared.d/90-rpi-usb-gadget-lease.conf
MOTD_FILE=/etc/update-motd.d/99-rpi-usb-gadget

MODE=preferred
DO_REBOOT=false

for arg in "$@"; do
    case "$arg" in
        --legacy)  MODE=legacy ;;
        --status)  MODE=status ;;
        --reboot)  DO_REBOOT=true ;;
        -h|--help)
            cat <<'USAGE'
Configure a Raspberry Pi as a USB-Ethernet (CDC-ECM) gadget so an iPad,
laptop, or other USB host can be tethered over the USB-C / OTG port.

Preferred path: Raspberry Pi OS Trixie's built-in `rpi-usb-gadget` package.
This script also installs a self-heal service for the known dwc2/iPadOS
failure where host->device packets stop arriving (169.254 self-assigned IP).

Usage:
  setup-rpi-usb-gadget.sh              configure (preferred path)
  sudo setup-rpi-usb-gadget.sh         same, as root
  setup-rpi-usb-gadget.sh --legacy     force the old manual g_ether setup
  setup-rpi-usb-gadget.sh --status     show current gadget state
  setup-rpi-usb-gadget.sh --reboot     reboot automatically when done

Safe to re-run: legacy config is cleaned up, the supported stack is
idempotent, and the helper units are rewritten each time.
USAGE
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

status() {
    if command -v rpi-usb-gadget >/dev/null 2>&1; then
        $SUDO rpi-usb-gadget status 2>/dev/null || true
    else
        echo "rpi-usb-gadget is not installed."
    fi
    echo
    echo ":: Interface"
    ip -br addr show usb0 2>/dev/null || echo "  usb0 not present"
    echo
    echo ":: DHCP leases on usb0"
    if [ -r /var/lib/NetworkManager/dnsmasq-usb0.leases ]; then
        now=$(date +%s)
        awk -v now="$now" '$1 ~ /^[0-9]+$/ && $1 > now {printf "  %s  %s  %s  (expires %s)\n", $2, $3, ($4 == "*" ? "" : $4), strftime("%H:%M:%S", $1)}' \
            /var/lib/NetworkManager/dnsmasq-usb0.leases 2>/dev/null || true
    else
        echo "  (lease file not readable; run as root for details)"
    fi
    echo
    echo ":: UDC state"
    for u in /sys/class/udc/*; do
        [ -e "$u" ] || continue
        printf '  %s: %s (%s)\n' "$(basename "$u")" "$(cat "$u/state" 2>/dev/null)" "$(cat "$u/current_speed" 2>/dev/null)"
    done
    echo
    echo ":: Self-heal service"
    systemctl is-enabled usb-gadget-selfheal.service 2>/dev/null || echo "not installed"
}

if [ "$MODE" = "status" ]; then
    status
    exit 0
fi

# --- Clean up previous hand-rolled config ----------------------------------
cleanup_legacy() {
    echo "==> Removing legacy hand-rolled gadget config (if present)..."

    if [ -f "$CMDLINE" ] && grep -q 'modules-load=dwc2,g_ether' "$CMDLINE" 2>/dev/null; then
        $SUDO sed -i 's/ modules-load=dwc2,g_ether//g' "$CMDLINE"
        echo "    removed modules-load=dwc2,g_ether from $(basename "$CMDLINE")"
    fi

    if [ -f "$CONFIG" ] && grep -qE '^dtoverlay=dwc2[[:space:]]*$' "$CONFIG" 2>/dev/null; then
        $SUDO sed -i -E '/^dtoverlay=dwc2[[:space:]]*$/d' "$CONFIG"
        echo "    removed bare dtoverlay=dwc2 from $(basename "$CONFIG")"
    fi

    if command -v nmcli >/dev/null 2>&1 && nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$LEGACY_PROFILE"; then
        $SUDO nmcli connection delete "$LEGACY_PROFILE" >/dev/null 2>&1 || true
        echo "    deleted NetworkManager profile $LEGACY_PROFILE"
    fi

    if systemctl list-unit-files usbgadget.service >/dev/null 2>&1; then
        $SUDO systemctl disable --now usbgadget.service >/dev/null 2>&1 || true
    fi
    for unit in "$LEGACY_UNIT" "$LEGACY_UNIT_LIB"; do
        if [ -f "$unit" ]; then
            $SUDO rm -f "$unit"
            echo "    removed $unit"
        fi
    done
    if [ -f "$LEGACY_BRINGUP" ]; then
        $SUDO rm -f "$LEGACY_BRINGUP"
        echo "    removed $LEGACY_BRINGUP"
    fi

    # The old soft_connect helper cannot work: this dwc2 rejects the write
    # ("udc ...: unsupported command"). Replace it with the self-heal unit.
    if systemctl list-unit-files usb-gadget-renotify.service >/dev/null 2>&1; then
        $SUDO systemctl disable --now usb-gadget-renotify.service >/dev/null 2>&1 || true
    fi
    for f in "$OLD_RENOTIFY_UNIT" "$OLD_RENOTIFY_SCRIPT"; do
        if [ -f "$f" ]; then
            $SUDO rm -f "$f"
            echo "    removed $f"
        fi
    done
    $SUDO systemctl daemon-reload >/dev/null 2>&1 || true
}

# --- Supported path: rpi-usb-gadget ----------------------------------------
install_package() {
    echo "==> Installing rpi-usb-gadget..."
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq || true
        $SUDO apt-get install -y rpi-usb-gadget
    fi
}

enable_supported() {
    echo "==> Enabling USB gadget via rpi-usb-gadget..."
    # 'on' must come first; -f suppresses the interactive model prompt.
    $SUDO rpi-usb-gadget on -f
    if command -v nmcli >/dev/null 2>&1; then
        $SUDO nmcli device set usb0 managed yes >/dev/null 2>&1 || true
    fi
}

# --- Legacy fallback --------------------------------------------------------
legacy_setup() {
    echo "==> Legacy mode: configuring g_ether manually..."

    $SUDO mkdir -p /etc/modules-load.d
    printf 'g_ether\n' | $SUDO tee /etc/modules-load.d/usb-gadget.conf >/dev/null

    if [ -f "$CONFIG" ]; then
        $SUDO sed -i -E '/^dtoverlay=dwc2([[:space:]]|,|$)/d' "$CONFIG"
        printf 'dtoverlay=dwc2,dr_mode=peripheral\n' | $SUDO tee -a "$CONFIG" >/dev/null
    fi

    if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$LEGACY_PROFILE"; then
        echo "    Updating existing profile $LEGACY_PROFILE."
    else
        $SUDO nmcli connection add type ethernet con-name "$LEGACY_PROFILE" \
            ifname usb0 ipv4.method shared ipv4.addresses 10.42.0.1/24 ipv6.method disabled
    fi
    $SUDO nmcli connection modify "$LEGACY_PROFILE" \
        connection.autoconnect yes \
        connection.interface-name usb0 \
        ipv4.method shared \
        ipv4.addresses 10.42.0.1/24 \
        ipv6.method disabled

    $SUDO mkdir -p "$(dirname "$DNSMASQ_SNIPPET")"
    {
        printf '%s\n' '# Autogenerated by setup-rpi-usb-gadget.sh - safe to delete'
        printf '%s\n' 'dhcp-authoritative'
        printf '%s\n' 'dhcp-option=51,120'
    } | $SUDO tee "$DNSMASQ_SNIPPET" >/dev/null
}

# --- Stable gadget MACs -----------------------------------------------------
# u_ether randomises the MAC pair on every module load unless host_addr and
# dev_addr are pinned. Every reload/reboot would otherwise look like a brand
# new adapter to iPadOS, resetting its network state.
pin_macs() {
    echo "==> Pinning stable gadget MAC addresses..."

    local serial
    serial=$(awk '/^Serial/{print $3}' /proc/cpuinfo 2>/dev/null || true)
    [ -n "$serial" ] || serial=$(cat /etc/machine-id 2>/dev/null || echo unknown)

    mac_from_hash() {
        local first=$1 input=$2 h
        h=$(printf '%s' "$input" | md5sum | cut -c1-10)
        printf '%s:%s:%s:%s:%s:%s' "$first" \
            "${h:0:2}" "${h:2:2}" "${h:4:2}" "${h:6:2}" "${h:8:2}"
    }

    local host_addr dev_addr
    host_addr=$(mac_from_hash 02 "${serial}-host")
    dev_addr=$(mac_from_hash 06 "${serial}-dev")

    printf '# Autogenerated by setup-rpi-usb-gadget.sh - stable per-board MACs\n' | $SUDO tee "$MAC_CONF" >/dev/null
    printf 'options g_ether host_addr=%s dev_addr=%s\n' "$host_addr" "$dev_addr" | $SUDO tee -a "$MAC_CONF" >/dev/null
    echo "    host_addr=$host_addr dev_addr=$dev_addr"
}

# --- dwc2 self-heal ---------------------------------------------------------
# Known failure: after the host sends a burst of packets the dwc2 peripheral
# OUT endpoint wedges; host->device traffic stops (host falls back to a
# 169.254 address) while device->host keeps working. Reloading g_ether
# recovers it. Watch for the kernel's endpoint-timeout signature, and use a
# DHCP-lease/rx-packet fallback for wedges that log nothing.
install_selfheal() {
    echo "==> Installing dwc2 self-heal service..."

    $SUDO tee "$SELFHEAL_SCRIPT" >/dev/null <<'SELFHEAL_EOF'
#!/bin/sh
# Reload g_ether when the dwc2 gadget link wedges (host->device traffic dies,
# host falls back to 169.254.x.x). Recovery is rmmod/modprobe: unbind/bind of
# the dwc2 platform device was reported to bootloop, so it is not used.
set -u

IFACE="${USB_GADGET_IFACE:-usb0}"
UDC_ROOT="${USB_GADGET_UDC_ROOT:-/sys/class/udc}"
LEASE_FILE="${USB_GADGET_LEASE_FILE:-/var/lib/NetworkManager/dnsmasq-usb0.leases}"
GRACE="${USB_GADGET_HEAL_GRACE:-12}"
COOLDOWN="${USB_GADGET_HEAL_COOLDOWN:-45}"
MAX_HEALS="${USB_GADGET_HEAL_MAX:-4}"
RESET_AFTER="${USB_GADGET_HEAL_RESET:-300}"
POLL="${USB_GADGET_HEAL_POLL:-4}"

log() { printf '[usb-gadget-selfheal] %s\n' "$*"; }

udc_state() {
    for u in "$UDC_ROOT"/*; do
        [ -e "$u/state" ] || continue
        cat "$u/state" 2>/dev/null
        return 0
    done
    return 1
}

stat_val() { cat "/sys/class/net/$IFACE/statistics/$1" 2>/dev/null || echo 0; }

live_leases() {
    [ -r "$LEASE_FILE" ] || { echo 0; return; }
    now=$(date +%s)
    awk -v now="$now" '$1 ~ /^[0-9]+$/ && $1 > now {n++} END{print n+0}' "$LEASE_FILE"
}

has_marker() {
    dmesg 2>/dev/null | tail -n 40 | grep -qE \
        "dwc2_hsotg_ep_stop_xfr: timeout|dwc2_hsotg_txfifo_flush: timeout"
}

heal() {
    log "reloading g_ether to recover the USB link"
    rmmod g_ether 2>/dev/null || true
    sleep 1
    modprobe g_ether 2>/dev/null || true
    sleep 1
}

attached=0
attach_epoch=0
rx0=0
heals=0
last_heal=0

log "started (iface=$IFACE grace=${GRACE}s cooldown=${COOLDOWN}s max=${MAX_HEALS})"

while :; do
    st=$(udc_state || echo "")

    if [ "$st" != "configured" ]; then
        [ "$attached" -eq 1 ] && log "host detached"
        attached=0
        attach_epoch=0
        sleep "$POLL"
        continue
    fi

    now=$(date +%s)

    # Give up on a whole burst of retries rather than looping forever.
    if [ "$heals" -gt 0 ] && [ $((now - last_heal)) -ge "$RESET_AFTER" ]; then
        heals=0
    fi

    if [ "$attached" -eq 0 ]; then
        attached=1
        attach_epoch=$now
        rx0=$(stat_val rx_packets)
        log "host attached; watchdog armed (rx=$rx0)"
        sleep "$POLL"
        continue
    fi

    if [ "$(live_leases)" -gt 0 ]; then
        [ "$heals" -ne 0 ] && log "DHCP lease present; link healthy"
        heals=0
        sleep "$POLL"
        continue
    fi

    if [ $((now - attach_epoch)) -lt "$GRACE" ]; then
        sleep "$POLL"
        continue
    fi
    if [ "$heals" -ge "$MAX_HEALS" ]; then
        sleep "$POLL"
        continue
    fi
    if [ "$last_heal" -ne 0 ] && [ $((now - last_heal)) -lt "$COOLDOWN" ]; then
        sleep "$POLL"
        continue
    fi

    rx_now=$(stat_val rx_packets)
    if has_marker; then
        reason="dwc2 endpoint timeout logged"
    elif [ "$rx_now" -eq "$rx0" ]; then
        reason="no packets received from host"
    else
        reason="no DHCP lease (host sent $((rx_now - rx0)) packets)"
    fi

    log "$reason; recovery attempt $((heals + 1))/$MAX_HEALS"
    last_heal=$now
    heals=$((heals + 1))
    heal
    sleep "$POLL"
done
SELFHEAL_EOF
    $SUDO chmod 0755 "$SELFHEAL_SCRIPT"

    $SUDO tee "$SELFHEAL_UNIT" >/dev/null <<'UNIT_EOF'
[Unit]
Description=USB gadget self-heal (dwc2 endpoint wedge recovery)
After=NetworkManager.service
Wants=NetworkManager.service
StartLimitIntervalSec=0

[Service]
Type=simple
Environment=USB_GADGET_IFACE=usb0
ExecStart=/usr/local/sbin/usb-gadget-selfheal.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT_EOF

    $SUDO systemctl daemon-reload
    $SUDO systemctl enable usb-gadget-selfheal.service >/dev/null 2>&1 || true
    $SUDO systemctl restart usb-gadget-selfheal.service >/dev/null 2>&1 || true
}

# --- Silence the Windows-only login hint -----------------------------------
silence_motd() {
    if [ -f "$MOTD_FILE" ]; then
        $SUDO chmod -x "$MOTD_FILE"
        echo "==> Silenced the Windows RNDIS login hint ($MOTD_FILE)."
    fi
}

# --- Main -------------------------------------------------------------------
cleanup_legacy

if [ "$MODE" = "legacy" ]; then
    legacy_setup
elif command -v rpi-usb-gadget >/dev/null 2>&1; then
    enable_supported
else
    if install_package 2>/dev/null && command -v rpi-usb-gadget >/dev/null 2>&1; then
        enable_supported
    else
        echo "==> rpi-usb-gadget unavailable; falling back to legacy mode." >&2
        legacy_setup
    fi
fi

pin_macs
install_selfheal
silence_motd

echo
echo "==> Current state:"
status

echo
if [ "$MODE" = "legacy" ] || ! command -v rpi-usb-gadget >/dev/null 2>&1; then
    echo "Pi address on USB: 10.42.0.1  (legacy subnet)"
else
    echo "Pi address on USB: 10.12.194.1  (rpi-usb-gadget shared subnet)"
fi
echo
echo "The self-heal service starts immediately; if the host is already plugged"
echo "in it will re-enumerate the gadget once the DHCP grace period expires."
echo
echo "A reboot is recommended to apply the overlay/module changes:"
echo "    sudo reboot"
echo
echo "After reconnecting the iPad, verify the DHCP exchange with:"
echo "    sudo tcpdump -i usb0 -n -e port 67 or port 68"
echo "and watch the self-heal decisions with:"
echo "    journalctl -u usb-gadget-selfheal.service -f"

if [ "$DO_REBOOT" = true ]; then
    echo
    echo "==> Rebooting..."
    $SUDO reboot
fi
