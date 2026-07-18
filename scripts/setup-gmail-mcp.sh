#!/usr/bin/env bash
set -euo pipefail

GMCP_DIR="${HOME}/.config/gmail-mcp"
CREDS="${GMCP_DIR}/credentials.json"
TOKEN="${GMCP_DIR}/token.json"
AUTH_SCRIPT="$(dirname "$0")/gmail-mcp-auth.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

info "Gmail MCP Setup"
echo "──────────────────────────────"

# Step 1: Check uv
if ! command -v uv &>/dev/null; then
    error "uv is not installed. Install it first: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
info "uv found: $(uv --version)"

# Step 2: Create directory
mkdir -p "${GMCP_DIR}"
info "Directory: ${GMCP_DIR}"

# Step 3: Check credentials.json
if [ ! -f "${CREDS}" ]; then
    warn "credentials.json not found at ${CREDS}"
    echo ""
    echo "You need to create OAuth credentials in Google Cloud Console:"
    echo "  1. Go to https://console.cloud.google.com/"
    echo "  2. Create a new project (or select existing)"
    echo "  3. Enable Gmail API (APIs & Services → Library → search 'Gmail API' → Enable)"
    echo "  4. Configure OAuth consent screen (External → Testing → add your email as test user)"
    echo "  5. Create OAuth 2.0 Client ID (Desktop app type → Download JSON)"
    echo "  6. Place the downloaded file at:"
    echo "       ${CREDS}"
    echo ""
    read -rp "Press Enter after you've placed credentials.json in place..."
    if [ ! -f "${CREDS}" ]; then
        error "credentials.json still not found. Aborting."
        exit 1
    fi
fi
info "credentials.json found"

# Step 4: Check or run OAuth auth
if [ -f "${TOKEN}" ]; then
    info "token.json already exists — skipping OAuth"
else
    echo ""
    info "Running OAuth authorization..."
    echo ""

    # Generate the auth URL
    uv run "${AUTH_SCRIPT}"
    echo ""

    echo "────────────────────────────────────────────────────────────"
    echo "1. Open the URL above in your browser"
    echo "2. Sign in with your Google account"
    echo "3. Click 'Continue' → grant permissions"
    echo "4. The browser will redirect to a broken localhost page"
    echo "5. Copy the FULL URL from the address bar"
    echo "6. Paste it below and press Enter"
    echo "────────────────────────────────────────────────────────────"
    echo ""
    read -rp "Redirect URL: " redirect_url

    # Extract code and exchange
    uv run "${AUTH_SCRIPT}" "${redirect_url}"
    echo ""

    if [ -f "${TOKEN}" ]; then
        info "OAuth token obtained successfully!"
    else
        error "Failed to obtain token. Run manually:"
        echo "  uv run ${AUTH_SCRIPT} 'YOUR_CODE'"
        exit 1
    fi
fi

# Step 5: Verify opencode config
OC_CONFIG="${HOME}/.config/opencode/opencode.json"
if [ -f "${OC_CONFIG}" ] && grep -q "gmail" "${OC_CONFIG}" 2>/dev/null; then
    info "OpenCode config has Gmail MCP entry"
else
    warn "OpenCode config not found or missing Gmail MCP entry."
    echo "Run 'home-manager switch --flake ~/dotfiles' to apply the HM module."
fi

# Step 6: Test connection
echo ""
if command -v opencode &>/dev/null; then
    info "Testing MCP connection..."
    opencode mcp list 2>/dev/null | grep -q "gmail" && \
        info "Gmail MCP server is connected!" || \
        warn "Gmail MCP not connected yet. Restart OpenCode."
fi

echo ""
info "Setup complete!"
echo ""
echo "Try asking OpenCode:"
echo "  • 'Show my unread emails'"
echo "  • 'Search for emails about [topic]'"
echo "  • 'Send an email to myself'"
