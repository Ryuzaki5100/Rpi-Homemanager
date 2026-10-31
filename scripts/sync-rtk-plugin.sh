#!/usr/bin/env bash
# Sync the RTK OpenCode plugin from upstream, pinned to the rtk version that
# the locked nixpkgs will install. Run automatically by update-home-manager
# and rebuild-home-manager.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
TARGET="${REPO}/modules/common/rtk-opencode.ts"
FLOOR="0.52.0" # first release with the OpenCode 2 dual-entrypoint plugin

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[rtk-sync]${NC} $*"; }
warn()  { echo -e "${YELLOW}[rtk-sync]${NC} $*"; }
error() { echo -e "${RED}[rtk-sync]${NC} $*"; }

if [ ! -d "${REPO}/.git" ]; then
  error "cannot find repo root at ${REPO}"
  exit 1
fi

ver="$(nix eval --raw --inputs-from "${REPO}" nixpkgs#rtk.version 2>/dev/null | tr -d '[:space:]')"
if [ -z "${ver}" ]; then
  warn "could not determine rtk version from the locked nixpkgs"
  if [ -s "${TARGET}" ]; then
    warn "keeping existing ${TARGET}"
    exit 0
  fi
  error "no rtk version and no vendored plugin to fall back to"
  exit 1
fi

# sort -V floor check: the smaller of floor/ver must be the floor.
if [ "$(printf '%s\n%s\n' "${FLOOR}" "${ver}" | sort -V | head -n1)" != "${FLOOR}" ]; then
  error "locked rtk ${ver} < ${FLOOR} — OpenCode 2 plugin support is missing."
  error "Run 'update-home-manager' first to bump nixpkgs, or set a newer rtk pin."
  exit 1
fi

url="https://raw.githubusercontent.com/rtk-ai/rtk/v${ver}/hooks/opencode/rtk.ts"
body="$(curl -fsSL "${url}" 2>/dev/null || true)"
if [ -z "${body}" ]; then
  warn "no plugin at tag v${ver}; falling back to develop"
  url="https://raw.githubusercontent.com/rtk-ai/rtk/develop/hooks/opencode/rtk.ts"
  body="$(curl -fsSL "${url}" 2>/dev/null || true)"
fi

if [ -z "${body}" ]; then
  if [ -s "${TARGET}" ]; then
    warn "could not fetch plugin (network/upstream); keeping existing ${TARGET}"
    exit 0
  fi
  error "could not fetch plugin and ${TARGET} does not exist"
  exit 1
fi

if ! grep -q "RtkOpenCodePlugin" <<<"${body}"; then
  error "fetched plugin does not look like the RTK OpenCode plugin; aborting"
  exit 1
fi

sha="$(printf '%s' "${body}" | shasum -a 256 | awk '{print $1}')"
tmp="$(mktemp)"
{
  echo "// Vendored from ${url}"
  echo "// rtk ${ver} — sha256 ${sha}"
  echo "// Synced by scripts/sync-rtk-plugin.sh — do not edit by hand."
  echo ""
  printf '%s\n' "${body}"
} > "${tmp}"

if [ -f "${TARGET}" ] && cmp -s "${tmp}" "${TARGET}"; then
  info "plugin already up to date (rtk ${ver})"
  rm -f "${tmp}"
else
  mv "${tmp}" "${TARGET}"
  info "wrote ${TARGET} (rtk ${ver})"
fi
