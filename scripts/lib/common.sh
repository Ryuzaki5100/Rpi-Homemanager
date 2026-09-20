#!/usr/bin/env bash
# shellcheck shell=bash
#
# Shared helpers for the dotfiles scripts.
#
# Everything here is CPU-architecture agnostic: it detects the host at runtime
# and exposes flags so individual scripts never hardcode aarch64/x86_64.
#
# Source it from a script with:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/common.sh"
#
# Exposes:
#   ARCH          uname -m (x86_64, aarch64, armv7l, ...)
#   IS_X86        true on x86_64 / amd64
#   IS_ARM        true on aarch64 / arm64 / armv7l / armv6l / arm
#   IS_RPI        true on a Raspberry Pi (ARM + Pi firmware/device-tree)
#   have CMD      return 0 if CMD is on PATH
#   require_rpi   print a skip message and return 1 when not on a Pi
#   host_ip       first non-loopback IPv4 (portable across minimal systems)

# These are consumed by the script that sources this file, not here.
# shellcheck disable=SC2034

# --- Architecture detection ---------------------------------------------------

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64 | amd64) IS_X86=true ;;
    *)              IS_X86=false ;;
esac

case "$ARCH" in
    aarch64 | arm64 | armv7l | armv6l | arm) IS_ARM=true ;;
    *)                                      IS_ARM=false ;;
esac

# A Raspberry Pi is ARM *and* exposes Pi firmware / device-tree. This keeps
# generic ARM machines from being treated as a Pi.
IS_RPI=false
if [ "$IS_ARM" = true ]; then
    if [ -r /proc/device-tree/model ] &&
        tr -d '\0' < /proc/device-tree/model 2>/dev/null | grep -qi 'raspberry pi'; then
        IS_RPI=true
    elif [ -f /boot/firmware/config.txt ] || [ -f /boot/config.txt ]; then
        IS_RPI=true
    fi
fi

# --- Helpers ------------------------------------------------------------------

have() {
    command -v "$1" >/dev/null 2>&1
}

# require_rpi [name] — callers use: require_rpi "$0" || exit 0
require_rpi() {
    local name="${1:-$(basename "${BASH_SOURCE[1]:-$0}")}"
    if [ "$IS_RPI" != true ]; then
        echo "$name: Raspberry Pi-only helper; detected architecture '$ARCH'. Skipping."
        return 1
    fi
    return 0
}

# First non-loopback IPv4. `hostname -I` is a GNU extension and not always
# installed (e.g. minimal Arch), so fall back to `ip route`.
host_ip() {
    local ip=""
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [ -z "$ip" ]; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null |
            awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}' || true)"
    fi
    printf '%s\n' "$ip"
}
