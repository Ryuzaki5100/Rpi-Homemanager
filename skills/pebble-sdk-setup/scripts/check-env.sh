#!/usr/bin/env bash
set -u
fail=0
say() { printf '%s\n' "$*"; }
check() { if "$@" >/dev/null 2>&1; then say "ok   $*"; else say "FAIL $*"; fail=1; fi; }

say "OS: $(uname -s) $(uname -m)"
check command -v pebble
check command -v qemu-pebble
check command -v pebble-python
check command -v node
check command -v npm

if command -v pebble >/dev/null 2>&1; then
  say "pebble: $(pebble --version 2>&1 | head -1)"
  say "--- pebble sdk list ---"
  pebble sdk list 2>&1 | head -8
fi

if command -v qemu-pebble >/dev/null 2>&1; then
  say "qemu: $(qemu-pebble --version 2>&1 | head -1)"
fi
if command -v pebble-python >/dev/null 2>&1; then
  pebble-python -c 'import PIL; print("Pillow:", PIL.__version__)' 2>&1 || fail=1
fi
if command -v node >/dev/null 2>&1; then
  say "node: $(node --version)"
fi

sdk_current="$HOME/Library/Application Support/Pebble SDK/SDKs/current"
[ -e "$sdk_current" ] || sdk_current="$HOME/.pebble-sdk/SDKs/current"
say "SDK current: $sdk_current"
[ -e "$sdk_current/sdk-core/manifest.json" ] || { say "FAIL SDK manifest missing"; fail=1; }
if [ -x "$sdk_current/toolchain/moddable-tools/mcrun" ]; then
  say "ok   mcrun (SDK toolchain)"
else
  say "FAIL mcrun (SDK toolchain)"; fail=1
fi

exit "$fail"
