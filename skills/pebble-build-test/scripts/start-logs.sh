#!/usr/bin/env bash
set -euo pipefail
platform="${1:-emery}"
if [ -f .pebble-logs.pid ] && kill -0 "$(cat .pebble-logs.pid)" 2>/dev/null; then
  echo "logs already running (pid $(cat .pebble-logs.pid))"
  exit 0
fi
PYTHONUNBUFFERED=1 pebble logs --emulator "$platform" > pebble-logs.txt 2>&1 &
echo $! > .pebble-logs.pid
echo "logging to pebble-logs.txt (pid $(cat .pebble-logs.pid))"
