#!/usr/bin/env bash
set -euo pipefail

# Configure a Raspberry Pi as a USB-Ethernet (CDC-ECM) gadget so an iPad,
# laptop, or other USB host can be tethered over the USB-C / OTG port.
#
# Preferred path: Raspberry Pi OS Trixie's built-in `rpi-usb-gadget` package
# (dwc2 overlay with dr_mode=peripheral, modules-load, NetworkManager
# client/shared profiles, ISO watcher).
#
# Pi 5 caveat: the USB-C port is the ONLY device-capable port AND the power
# input, so when an iPad powers the board the bootloader's USB-PD request makes
# iPadOS kill the USB 2.0 data lines (and sometimes VBUS). The fix is
# PSU_MAX_CURRENT=3000 in the bootloader EEPROM, which skips PD negotiation.
# This script refuses to enable gadget mode on a Pi 5 without it.
#
# Everything this script edits is backed up to
# /boot/firmware/{config.txt,cmdline.txt}.rpi-usb-gadget.bak, so a bad boot is
# recoverable by mounting the boot partition on another machine. `--restore`
# reverses the whole setup.
#
# Usage:
#   setup-rpi-usb-gadget.sh                    # configure (preferred path)
#   setup-rpi-usb-gadget.sh --legacy           # old known-good g_ether stack
#   setup-rpi-usb-gadget.sh --restore          # undo everything
#   setup-rpi-usb-gadget.sh --status           # current gadget state
#   setup-rpi-usb-gadget.sh --verify           # post-reboot health check
#   setup-rpi-usb-gadget.sh --diagnose         # one paste-able debugging dump
#   setup-rpi-usb-gadget.sh --dry-run          # show what would change
#   setup-rpi-usb-gadget.sh --psu-max-current 3000
#   setup-rpi-usb-gadget.sh --reboot           # reboot when done
#
# Safe to re-run: legacy config is cleaned up, the package path is idempotent,
# and helper units are rewritten each time.

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

MODEL=$(tr -d '\0' < /proc/device-tree/model)
IS_PI5=false
case "$MODEL" in
    *"Raspberry Pi 5"*|*"Compute Module 5"*) IS_PI5=true ;;
esac

CMDLINE=/boot/firmware/cmdline.txt
CONFIG=/boot/firmware/config.txt
[ -f "$CMDLINE" ] || CMDLINE=/boot/cmdline.txt
[ -f "$CONFIG" ] || CONFIG=/boot/config.txt
BACKUP_SUFFIX=.rpi-usb-gadget.bak

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
UDC_ROOT=/sys/class/udc

ACTION=setup
DRY_RUN=false
DO_REBOOT=false
PIN_MACS=false
FORCE=false
PSU_MAX_CURRENT=""
NEED_REBOOT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --legacy)  ACTION=legacy ;;
        --restore) ACTION=restore ;;
        --status)  ACTION=status ;;
        --verify)  ACTION=verify ;;
        --diagnose) ACTION=diagnose ;;
        --dry-run) DRY_RUN=true ;;
        --reboot)  DO_REBOOT=true ;;
        --pin-macs) PIN_MACS=true ;;
        --force)   FORCE=true ;;
        --psu-max-current=*) PSU_MAX_CURRENT="${1#*=}" ;;
        --psu-max-current)
            PSU_MAX_CURRENT="${2:-}"
            [ -n "$PSU_MAX_CURRENT" ] || { echo "--psu-max-current needs a value" >&2; exit 1; }
            shift
            ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# --- helpers ---------------------------------------------------------------
x() {
    if [ "$DRY_RUN" = true ]; then
        printf '    [dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

put() {
    local mode=$1 dest=$2 tmp
    tmp=$(mktemp)
    cat >"$tmp"
    if [ "$DRY_RUN" = true ]; then
        printf '    [dry-run] would write %s (%s):\n' "$dest" "$mode"
        sed 's/^/        /' "$tmp"
        rm -f "$tmp"
        return 0
    fi
    $SUDO install -m "$mode" "$tmp" "$dest"
    rm -f "$tmp"
}

udc_present() {
    for u in "$UDC_ROOT"/*; do
        [ -e "$u" ] && return 0
    done
    return 1
}

udc_state() {
    for u in "$UDC_ROOT"/*; do
        [ -e "$u/state" ] || continue
        cat "$u/state" 2>/dev/null
        return 0
    done
    return 1
}

psu_applied() {
    vcgencmd bootloader_config 2>/dev/null | sed -n 's/^PSU_MAX_CURRENT=//p' | head -n1
}

psu_pending() {
    local img=/boot/firmware/pieeprom.upd
    [ -r "$img" ] || return 0
    rpi-eeprom-config "$img" 2>/dev/null | sed -n 's/^PSU_MAX_CURRENT=//p' | head -n1 || true
}

max_current() {
    local f=/proc/device-tree/chosen/power/max_current
    [ -r "$f" ] || return 0
    od -An -tu4 --endian=big "$f" 2>/dev/null | tr -d ' '
}

decode_throttled() {
    local v=$1 out=""
    [ -n "$v" ] || { echo "unknown"; return; }
    local n=$((v))
    (( n & 0x1 )) && out="$out under-voltage-now"
    (( n & 0x2 )) && out="$out freq-capped-now"
    (( n & 0x4 )) && out="$out throttled-now"
    (( n & 0x8 )) && out="$out soft-temp-limit-now"
    (( n & 0x10000 )) && out="$out under-voltage-since-boot"
    (( n & 0x20000 )) && out="$out freq-capped-since-boot"
    (( n & 0x40000 )) && out="$out throttled-since-boot"
    (( n & 0x80000 )) && out="$out soft-temp-limit-since-boot"
    [ -n "$out" ] || out=" none"
    echo "${out# }"
}

# --- status / verify -------------------------------------------------------
status() {
    echo ":: Board"
    printf '  model:        %s\n' "$MODEL"
    printf '  kernel:       %s\n' "$(uname -r)"
    printf '  bootloader:   %s\n' "$(vcgencmd bootloader_version 2>/dev/null | head -n1)"
    printf '  PSU_MAX_CURRENT: applied=%s pending=%s\n' \
        "$(psu_applied || true)" "$(psu_pending || true)"
    printf '  max_current:  %s (mA reported by firmware)\n' "$(max_current)"
    printf '  throttled:    %s -> %s\n' "$(vcgencmd get_throttled)" "$(decode_throttled "$(vcgencmd get_throttled | cut -d= -f2)")"

    echo
    echo ":: Gadget"
    if command -v rpi-usb-gadget >/dev/null 2>&1; then
        printf '  package:      installed\n'
    else
        printf '  package:      not installed\n'
    fi
    printf '  UDC:          %s\n' "$(udc_state || echo none)"
    ip -br addr show usb0 2>/dev/null || echo "  usb0:         not present"
    if command -v nmcli >/dev/null 2>&1; then
        printf '  NM profile:   %s\n' "$(nmcli -g GENERAL.CONNECTION device show usb0 2>/dev/null || echo -)"
    fi

    echo
    echo ":: Services"
    printf '  ics watcher:  enabled=%s active=%s\n' \
        "$(systemctl is-enabled --quiet rpi-usb-gadget-ics.service 2>/dev/null && echo yes || echo no)" \
        "$(systemctl is-active --quiet rpi-usb-gadget-ics.service 2>/dev/null && echo yes || echo no)"
    printf '  self-heal:    enabled=%s active=%s\n' \
        "$(systemctl is-enabled --quiet usb-gadget-selfheal.service 2>/dev/null && echo yes || echo no)" \
        "$(systemctl is-active --quiet usb-gadget-selfheal.service 2>/dev/null && echo yes || echo no)"

    echo
    echo ":: Host on usb0"
    local neigh ip4
    neigh=$(ip neigh show dev usb0 2>/dev/null | head -n 5)
    ip4=$(ip -4 -o addr show dev usb0 2>/dev/null | awk 'NR==1 {print $4}')
    if [ -n "$neigh" ]; then
        printf '%s\n' "$neigh" | sed 's/^/  /'
    else
        echo "  no neighbour entry yet (no traffic from a host)"
    fi
    if [ -n "$ip4" ]; then
        echo "  health: healthy (usb0 has $ip4)"
    else
        echo "  health: no IPv4 on usb0"
    fi

    echo
    echo ":: DHCP leases on usb0 (optional; this NM version does not always write one)"
    if [ -r /var/lib/NetworkManager/dnsmasq-usb0.leases ]; then
        now=$(date +%s)
        awk -v now="$now" '$1 ~ /^[0-9]+$/ && $1 > now {printf "  %s  %s  %s  (expires %s)\n", $2, $3, ($4 == "*" ? "" : $4), strftime("%H:%M:%S", $1)}' \
            /var/lib/NetworkManager/dnsmasq-usb0.leases 2>/dev/null || true
    else
        echo "  (no lease file - not an error: the neighbour entry above is the real signal)"
    fi
}

diagnose() {
    status
    echo
    verify || true
    echo
    echo ":: Boot config"
    grep -n 'dtoverlay=dwc2' "$CONFIG" 2>/dev/null | sed 's/^/  config.txt: /' || echo "  config.txt: no dwc2 overlay"
    grep -o 'modules-load=[^ ]*' "$CMDLINE" 2>/dev/null | sed 's/^/  cmdline.txt: /' || true
    [ -f /etc/modules-load.d/usb-gadget.conf ] && sed 's/^/  modules-load.d: /' /etc/modules-load.d/usb-gadget.conf
    echo
    echo ":: Kernel modules"
    lsmod 2>/dev/null | grep -E '^(g_ether|dwc2|usb_f_ecm|libcomposite)\b' | sed 's/^/  /' || echo "  none"
    echo
    echo ":: usb0 link"
    ip -d link show usb0 2>/dev/null | sed 's/^/  /' || echo "  usb0 missing"
    echo
    echo ":: dmesg (usb)"
    dmesg 2>/dev/null | grep -iE 'dwc2|g_ether|usb0|cable|over-?current' | tail -n 20 | sed 's/^/  /' || true
    echo
    echo ":: Failed units"
    systemctl --no-pager --failed 2>/dev/null | sed 's/^/  /' || true
}

verify() {
    local rc=0
    echo "==> Verifying USB gadget state"
    [ "$IS_PI5" = true ] && echo "    Pi 5: the host must supply power over USB-C or the board must be PoE/GPIO powered"

    local psu pending
    psu=$(psu_applied)
    pending=$(psu_pending)
    if [ "$IS_PI5" = true ]; then
        if [ -n "$psu" ]; then
            echo "    OK   PSU_MAX_CURRENT=$psu"
        elif [ -n "$pending" ]; then
            echo "    WARN PSU_MAX_CURRENT=$pending pending in EEPROM update (reboot to apply)"
        else
            echo "    FAIL PSU_MAX_CURRENT is unset (USB-PD will kill the iPad link)"; rc=1
        fi
    fi

    local udc
    if udc_present; then
        udc=$(udc_state)
        echo "    OK   UDC present: $udc"
    else
        udc=""
        echo "    FAIL no /sys/class/udc entries (overlay not active: reboot?)"; rc=1
    fi

    if ip -br addr show usb0 2>/dev/null | grep -q 'UP'; then
        echo "    OK   usb0: $(ip -br addr show usb0 | tr -s ' ')"
    elif [ "$udc" != "configured" ]; then
        echo "    SKIP usb0 down (no host attached yet: plug in the iPad)"
    else
        echo "    FAIL host attached but usb0 is down"; rc=1
    fi

    local th
    th=$(vcgencmd get_throttled | cut -d= -f2)
    if [ "$th" = "0x0" ]; then
        echo "    OK   throttled=0x0"
    else
        echo "    WARN throttled=$th -> $(decode_throttled "$th")"
    fi

    echo "    -- dmesg (dwc2/g_ether) --"
    dmesg 2>/dev/null | grep -iE 'dwc2|g_ether|usb0' | tail -n 8 | sed 's/^/       /' || true
    return "$rc"
}

# --- boot-file backups -----------------------------------------------------
backup_boot_files() {
    echo "==> Backing up boot files"
    for f in "$CONFIG" "$CMDLINE"; do
        [ -f "$f" ] || continue
        local bak="$f$BACKUP_SUFFIX"
        if [ -f "$bak" ]; then
            echo "    keeping existing $bak"
        else
            x $SUDO cp -a "$f" "$bak"
            echo "    $(basename "$f") -> $(basename "$bak")"
        fi
    done
}

# --- Pi 5 power-delivery preflight -----------------------------------------
ensure_psu_max_current() {
    [ "$IS_PI5" = true ] || return 0

    if [ -n "$PSU_MAX_CURRENT" ]; then
        echo "==> Setting PSU_MAX_CURRENT=$PSU_MAX_CURRENT in the bootloader EEPROM"
        local tmp
        tmp=$(mktemp)
        $SUDO rpi-eeprom-config >"$tmp"
        if grep -q '^PSU_MAX_CURRENT=' "$tmp"; then
            $SUDO sed -i "s/^PSU_MAX_CURRENT=.*/PSU_MAX_CURRENT=$PSU_MAX_CURRENT/" "$tmp"
        else
            printf 'PSU_MAX_CURRENT=%s\n' "$PSU_MAX_CURRENT" >>"$tmp"
        fi
        if [ "$DRY_RUN" = true ]; then
            printf '    [dry-run] would apply EEPROM config:\n'
            sed 's/^/        /' "$tmp"
        else
            $SUDO rpi-eeprom-config --apply "$tmp"
            NEED_REBOOT=true
        fi
        rm -f "$tmp"
        return 0
    fi

    local applied pending
    applied=$(psu_applied)
    pending=$(psu_pending)
    if [ -n "$applied" ]; then
        echo "==> PSU_MAX_CURRENT=$applied (PD negotiation disabled)"
        return 0
    fi
    if [ -n "$pending" ]; then
        echo "==> PSU_MAX_CURRENT=$pending pending in the EEPROM update (applies on reboot)"
        NEED_REBOOT=true
        return 0
    fi

    cat >&2 <<EOF
ERROR: $MODEL has no PSU_MAX_CURRENT in the bootloader config.

On a Pi 5 the USB-C port is both the gadget port and the power input. Without
this setting the bootloader sends a USB-PD request, iPadOS drops the USB 2.0
data lines, and (worst case) VBUS goes away and the Pi dies mid-write.

Fix it once with:
    sudo rpi-eeprom-config > /tmp/bootconf.txt
    grep -q '^PSU_MAX_CURRENT=' /tmp/bootconf.txt \\
      && sudo sed -i 's/^PSU_MAX_CURRENT=.*/PSU_MAX_CURRENT=3000/' /tmp/bootconf.txt \\
      || echo 'PSU_MAX_CURRENT=3000' | sudo tee -a /tmp/bootconf.txt
    sudo rpi-eeprom-config --apply /tmp/bootconf.txt
    sudo reboot

or re-run this script with --psu-max-current 3000. Use --force to skip the
check (only if the board is powered by PoE or the GPIO 5V pins).
EOF
    [ "$FORCE" = true ] || exit 1
    echo "    WARNING: continuing anyway because --force was given" >&2
}

# --- package path ----------------------------------------------------------
ensure_package() {
    if command -v rpi-usb-gadget >/dev/null 2>&1; then
        echo "==> rpi-usb-gadget already installed"
        return 0
    fi
    command -v apt-get >/dev/null 2>&1 || {
        echo "ERROR: apt-get not found. Re-run with --legacy." >&2
        exit 1
    }
    echo "==> Installing rpi-usb-gadget..."
    x $SUDO apt-get update -qq || true
    if ! x $SUDO apt-get install -y rpi-usb-gadget; then
        cat >&2 <<'EOF'
ERROR: rpi-usb-gadget could not be installed (offline or missing repo).
Nothing else was changed. Re-run when apt works, or use --legacy explicitly.
EOF
        exit 1
    fi
    command -v rpi-usb-gadget >/dev/null 2>&1 || {
        echo "ERROR: rpi-usb-gadget still not found after install." >&2
        exit 1
    }
}

enable_supported() {
    echo "==> Enabling USB gadget via rpi-usb-gadget"
    # 'on' must come first; -f suppresses the interactive model prompt.
    x $SUDO rpi-usb-gadget on -f
    if command -v nmcli >/dev/null 2>&1 && ip link show usb0 >/dev/null 2>&1; then
        x $SUDO nmcli device set usb0 managed yes || true
    fi
    if udc_present; then
        echo "    UDC present: $(udc_state)"
    else
        echo "    overlay written but no UDC yet (reboot required)"
        NEED_REBOOT=true
    fi
}

# --- legacy fallback: the previously-known-good stack ----------------------
legacy_setup() {
    echo "==> Legacy mode: g_ether + ethernet-usb0 (10.42.0.1/24)"

    # Never run two stacks at once.
    if command -v rpi-usb-gadget >/dev/null 2>&1; then
        x $SUDO rpi-usb-gadget off || true
    fi

    put 0644 /etc/modules-load.d/usb-gadget.conf <<'EOF'
g_ether
EOF

    if [ -f "$CMDLINE" ] && ! grep -q 'modules-load=dwc2,g_ether' "$CMDLINE"; then
        x $SUDO sed -i 's/$/ modules-load=dwc2,g_ether/' "$CMDLINE"
    fi

    if [ -f "$CONFIG" ] && ! grep -qx 'dtoverlay=dwc2' "$CONFIG"; then
        printf '\n[all]\ndtoverlay=dwc2\n' | $SUDO tee -a "$CONFIG" >/dev/null
    fi

    if command -v nmcli >/dev/null 2>&1; then
        if ! nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$LEGACY_PROFILE"; then
            x $SUDO nmcli connection add type ethernet con-name "$LEGACY_PROFILE" \
                ifname usb0 ipv4.method shared ipv4.addresses 10.42.0.1/24 ipv6.method disabled
        fi
        x $SUDO nmcli connection modify "$LEGACY_PROFILE" \
            connection.autoconnect yes \
            connection.interface-name usb0 \
            ipv4.method shared \
            ipv4.addresses 10.42.0.1/24 \
            ipv6.method disabled
    fi

    NEED_REBOOT=true
}

# --- remove old hand-rolled config -----------------------------------------
cleanup_legacy() {
    echo "==> Removing legacy hand-rolled gadget config (if present)"

    if [ -f "$CMDLINE" ] && grep -q 'modules-load=dwc2,g_ether' "$CMDLINE"; then
        x $SUDO sed -i 's/ modules-load=dwc2,g_ether//g' "$CMDLINE"
        echo "    removed modules-load=dwc2,g_ether from $(basename "$CMDLINE")"
    fi

    if [ -f "$CONFIG" ] && grep -qE '^dtoverlay=dwc2[[:space:]]*$' "$CONFIG"; then
        x $SUDO sed -i -E '/^dtoverlay=dwc2[[:space:]]*$/d' "$CONFIG"
        echo "    removed bare dtoverlay=dwc2 from $(basename "$CONFIG")"
    fi

    if command -v nmcli >/dev/null 2>&1 && nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$LEGACY_PROFILE"; then
        x $SUDO nmcli connection delete "$LEGACY_PROFILE" >/dev/null 2>&1 || true
        echo "    deleted NetworkManager profile $LEGACY_PROFILE"
    fi

    if systemctl list-unit-files usbgadget.service >/dev/null 2>&1; then
        x $SUDO systemctl disable --now usbgadget.service >/dev/null 2>&1 || true
    fi
    for unit in "$LEGACY_UNIT" "$LEGACY_UNIT_LIB" "$LEGACY_BRINGUP"; do
        if [ -f "$unit" ]; then
            x $SUDO rm -f "$unit"
            echo "    removed $unit"
        fi
    done

    if systemctl list-unit-files usb-gadget-renotify.service >/dev/null 2>&1; then
        x $SUDO systemctl disable --now usb-gadget-renotify.service >/dev/null 2>&1 || true
    fi
    for f in "$OLD_RENOTIFY_UNIT" "$OLD_RENOTIFY_SCRIPT"; do
        if [ -f "$f" ]; then
            x $SUDO rm -f "$f"
            echo "    removed $f"
        fi
    done
    x $SUDO systemctl daemon-reload || true
}

# --- optional: stable gadget MACs -----------------------------------------
pin_macs() {
    [ "$PIN_MACS" = true ] || return 0
    echo "==> Pinning stable gadget MAC addresses (opt-in)"

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

    put 0644 "$MAC_CONF" <<EOF
# Autogenerated by setup-rpi-usb-gadget.sh - stable per-board MACs
options g_ether host_addr=$host_addr dev_addr=$dev_addr
EOF
    echo "    host_addr=$host_addr dev_addr=$dev_addr"
}

# --- dwc2 self-heal (conservative) -----------------------------------------
# The dwc2 peripheral OUT endpoint can wedge: host->device traffic stops while
# device->host keeps working. Recovery is a g_ether reload, but only when the
# link is provably unhealthy on every axis we can observe, never while an SSH
# session rides on usb0, and at most once per attach.
install_selfheal() {
    echo "==> Installing conservative dwc2 self-heal service"

    put 0755 "$SELFHEAL_SCRIPT" <<'SELFHEAL_EOF'
#!/bin/sh
# Reload g_ether only when the gadget link is unhealthy by every measure we
# have: no IPv4 address on usb0, no neighbour entry, no rx_packets movement,
# and no SSH session riding on usb0. One reload per host attach.
set -u

IFACE="${USB_GADGET_IFACE:-usb0}"
UDC_ROOT="${USB_GADGET_UDC_ROOT:-/sys/class/udc}"
POLL="${USB_GADGET_HEAL_POLL:-5}"
SILENT_POLLS="${USB_GADGET_HEAL_SILENT_POLLS:-6}"
COOLDOWN="${USB_GADGET_HEAL_COOLDOWN:-60}"

log() { printf '[usb-gadget-selfheal] %s\n' "$*"; }

udc_state() {
    for u in "$UDC_ROOT"/*; do
        [ -e "$u/state" ] || continue
        cat "$u/state" 2>/dev/null
        return 0
    done
    echo none
}

iface_ipv4() {
    ip -4 -o addr show dev "$IFACE" 2>/dev/null | awk 'NR==1 {print $4}'
}

has_neighbour() {
    ip neigh show dev "$IFACE" 2>/dev/null | grep -qvE 'FAILED|INCOMPLETE'
}

rx_packets() {
    cat "/sys/class/net/$IFACE/statistics/rx_packets" 2>/dev/null || echo 0
}

ssh_over_iface() {
    for a in $(ip -4 -o addr show dev "$IFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1); do
        if ss -Htn state established '( sport = :22 )' 2>/dev/null | grep -q " $a:"; then
            return 0
        fi
    done
    return 1
}

g_ether_loaded() {
    grep -q '^g_ether ' /proc/modules 2>/dev/null
}

attached=0
silent=0
heals=0
last_heal=0
last_rx=0

log "started (iface=$IFACE poll=${POLL}s silent=${SILENT_POLLS} cooldown=${COOLDOWN}s)"

while :; do
    st=$(udc_state)
    if [ "$st" != "configured" ]; then
        [ "$attached" -eq 1 ] && log "host detached (udc=$st)"
        attached=0; silent=0; heals=0; last_heal=0
        sleep "$POLL"
        continue
    fi

    now=$(date +%s)

    if [ "$attached" -eq 0 ]; then
        attached=1; silent=0; heals=0; last_heal=0
        last_rx=$(rx_packets)
        log "host attached; watchdog armed (rx=$last_rx)"
        sleep "$POLL"
        continue
    fi

    if [ -n "$(iface_ipv4)" ] || has_neighbour || ssh_over_iface; then
        [ "$silent" -gt 0 ] && log "link healthy again; counters reset"
        silent=0
        sleep "$POLL"
        continue
    fi

    if [ "$heals" -ge 1 ]; then
        sleep "$POLL"
        continue
    fi

    rx=$(rx_packets)
    if [ "$rx" != "$last_rx" ]; then
        last_rx=$rx
        silent=0
        sleep "$POLL"
        continue
    fi

    silent=$((silent + 1))
    if [ "$silent" -lt "$SILENT_POLLS" ]; then
        sleep "$POLL"
        continue
    fi

    if [ "$last_heal" -ne 0 ] && [ $((now - last_heal)) -lt "$COOLDOWN" ]; then
        sleep "$POLL"
        continue
    fi

    if ! g_ether_loaded; then
        log "no address/neighbour/rx movement, but g_ether is not loaded; not reloading"
        sleep "$POLL"
        continue
    fi

    log "unhealthy for $((silent * POLL))s (no IPv4, no neighbour, no rx movement); reloading g_ether once for this attach"
    last_heal=$now
    heals=$((heals + 1))
    silent=0
    rmmod g_ether 2>/dev/null || true
    sleep 1
    modprobe g_ether 2>/dev/null || true
    sleep 2
    systemctl restart rpi-usb-gadget-ics.service 2>/dev/null || true
    last_rx=$(rx_packets)
    sleep "$POLL"
done
SELFHEAL_EOF

    put 0644 "$SELFHEAL_UNIT" <<'UNIT_EOF'
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
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT_EOF

    x $SUDO systemctl daemon-reload
    x $SUDO systemctl enable usb-gadget-selfheal.service >/dev/null 2>&1 || true
    x $SUDO systemctl restart usb-gadget-selfheal.service >/dev/null 2>&1 || true
}

# --- silence the Windows-only login hint -----------------------------------
silence_motd() {
    if [ -f "$MOTD_FILE" ]; then
        x $SUDO chmod -x "$MOTD_FILE"
        echo "==> Silenced the Windows RNDIS login hint ($MOTD_FILE)"
    fi
}

# --- restore ---------------------------------------------------------------
restore() {
    echo "==> Restoring pre-gadget configuration"

    if command -v rpi-usb-gadget >/dev/null 2>&1; then
        x $SUDO rpi-usb-gadget off || true
    fi

    x $SUDO systemctl disable --now usb-gadget-selfheal.service >/dev/null 2>&1 || true
    for f in "$SELFHEAL_UNIT" "$SELFHEAL_SCRIPT" "$MAC_CONF" "$DNSMASQ_SNIPPET" "$OLD_RENOTIFY_UNIT" "$OLD_RENOTIFY_SCRIPT"; do
        if [ -f "$f" ]; then
            x $SUDO rm -f "$f"
            echo "    removed $f"
        fi
    done

    if [ -f "$MOTD_FILE" ]; then
        x $SUDO chmod +x "$MOTD_FILE"
    fi

    if command -v nmcli >/dev/null 2>&1; then
        for name in "$LEGACY_PROFILE" "USB Gadget (client)" "USB Gadget (shared)"; do
            if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$name"; then
                x $SUDO nmcli connection delete "$name" >/dev/null 2>&1 || true
                echo "    deleted NetworkManager profile $name"
            fi
        done
        x $SUDO nmcli connection reload || true
    fi

    if systemctl list-unit-files usbgadget.service >/dev/null 2>&1; then
        x $SUDO systemctl disable --now usbgadget.service >/dev/null 2>&1 || true
    fi
    for f in "$LEGACY_UNIT" "$LEGACY_UNIT_LIB" "$LEGACY_BRINGUP"; do
        [ -f "$f" ] && { x $SUDO rm -f "$f"; echo "    removed $f"; }
    done

    x $SUDO systemctl daemon-reload || true

    for f in "$CONFIG" "$CMDLINE"; do
        local bak="$f$BACKUP_SUFFIX"
        if [ -f "$bak" ]; then
            x $SUDO cp -a "$bak" "$f"
            echo "    restored $f from $(basename "$bak")"
        else
            echo "    no backup for $f; leaving it alone"
        fi
    done

    NEED_REBOOT=true
}

# --- main ------------------------------------------------------------------
case "$ACTION" in
    status)
        status
        exit 0
        ;;
    verify)
        status
        echo
        verify
        exit $?
        ;;
    diagnose)
        diagnose
        exit 0
        ;;
esac

if [ "$ACTION" = "restore" ]; then
    restore
else
    # Verify the Pi 5 power path and take backups before changing anything.
    ensure_psu_max_current
    backup_boot_files

    if [ "$ACTION" = "legacy" ]; then
        legacy_setup
    else
        ensure_package
        cleanup_legacy
        enable_supported
    fi

    pin_macs
    install_selfheal
    silence_motd
fi

echo
echo "==> Current state"
status

echo
if [ "$ACTION" = "legacy" ]; then
    echo "Pi address on USB: 10.42.0.1 (legacy subnet)"
else
    echo "Pi address on USB: 10.12.194.1 (rpi-usb-gadget shared subnet)"
fi
echo
if [ "$NEED_REBOOT" = true ]; then
    echo "A reboot is required to apply the overlay / EEPROM changes:"
    echo "    sudo reboot"
    echo
    echo "Recovery if the board does not come back: power off, mount the boot"
    echo "partition on another machine and restore $(basename "$CONFIG")$BACKUP_SUFFIX"
    echo "and $(basename "$CMDLINE")$BACKUP_SUFFIX."
fi
echo
echo "After reconnecting the iPad:"
echo "    make rpi-usb-gadget-verify        # or: $0 --verify"
echo "    make rpi-usb-gadget-diagnose      # full dump to paste when it misbehaves"
echo "    journalctl -u usb-gadget-selfheal.service -f"
echo "    sudo tcpdump -i usb0 -n -e port 67 or port 68"

if [ "$DO_REBOOT" = true ] && [ "$DRY_RUN" = false ]; then
    echo
    echo "==> Rebooting..."
    $SUDO reboot
fi
