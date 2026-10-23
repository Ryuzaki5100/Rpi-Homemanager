#!/usr/bin/env bash
set -euo pipefail
platform="${1:-emery}"
out="${2:-screenshot_${platform}.png}"
mkdir -p "$(dirname "$out")"
pebble screenshot --no-open --emulator "$platform" "$out"
echo "$out"
