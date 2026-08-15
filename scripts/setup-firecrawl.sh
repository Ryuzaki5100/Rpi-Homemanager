#!/usr/bin/env bash
set -euo pipefail

FC_DIR="${HOME}/.config/firecrawl"
KEY_FILE="${FC_DIR}/api-key"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

info "Firecrawl API key setup"
echo "──────────────────────────────"

mkdir -p "${FC_DIR}"

if [ -f "${KEY_FILE}" ] && [ -s "${KEY_FILE}" ]; then
    warn "An API key already exists at ${KEY_FILE}"
    read -rp "Overwrite it? [y/N] " overwrite
    if [[ ! "${overwrite}" =~ ^[Yy]$ ]]; then
        info "Keeping existing key. Exiting."
        exit 0
    fi
fi

echo ""
echo "Get your key from https://www.firecrawl.dev/app/api-keys"
echo "It looks like: fc-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo ""
read -rsp "Paste your Firecrawl API key and press Enter: " api_key
echo ""

if [ -z "${api_key}" ]; then
    error "No key entered. Aborting."
    exit 1
fi

api_key="$(echo "${api_key}" | tr -d '[:space:]')"

if [[ ! "${api_key}" == fc-* ]]; then
    warn "Key doesn't start with 'fc-' - double-check it's a Firecrawl API key."
fi

printf '%s' "${api_key}" > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"

info "API key saved to ${KEY_FILE} (permissions 600)"

OC_CONFIG="${HOME}/.config/opencode/opencode.json"
if [ -f "${OC_CONFIG}" ] && grep -q "firecrawl" "${OC_CONFIG}" 2>/dev/null; then
    info "OpenCode config has Firecrawl MCP entry"
else
    warn "OpenCode config not found or missing Firecrawl MCP entry."
    echo "Run 'home-manager switch --flake ~/dotfiles#ryuzaki' to apply the HM module."
fi

echo ""
info "Done! Restart OpenCode for the Firecrawl MCP server to pick up the key."
