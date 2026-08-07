#!/usr/bin/env bash
set -euo pipefail

# One-shot reproducible Filebrowser setup for the RPi.
# - Applies the Home Manager flake (installs filebrowser + systemd unit)
# - Interactively sets (or updates) the admin password
# - Ensures DB, min password length, and TUS chunk size are configured
# - Starts the service and prints the access URL
#
# Idempotent: safe to re-run. Prompts for the password unless
# FILEBROWSER_PASSWORD is already set in the environment.

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DB="$HOME/.config/filebrowser/filebrowser.db"
USERNAME="${FILEBROWSER_USERNAME:-admin}"
TUS_CHUNK_SIZE="${FILEBROWSER_TUS_CHUNK_SIZE:-2147483648}"

say() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Ensure Nix + Home Manager from the flake -----------------------------

has_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! has_cmd nix; then
    die "Nix is not installed. Run first: scripts/install-nix.sh"
fi
if ! grep -q "^experimental-features = .*nix-command.*flakes" /etc/nix/nix.conf 2>/dev/null; then
    say "Enabling Nix flakes..."
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
fi

say "Applying Home Manager configuration from $DOTFILES"
cd "$DOTFILES"
if has_cmd home-manager; then
    home-manager switch --flake .#ryuzaki
else
    nix run github:nix-community/home-manager -- switch --flake .#ryuzaki
fi

# --- Password -----------------------------------------------------------------

if [ -z "${FILEBROWSER_PASSWORD:-}" ]; then
    echo ""
    printf 'Password for Filebrowser user "%s": ' "$USERNAME"
    read -rs PASSWORD
    echo
    printf 'Confirm password: '
    read -rs PASSWORD_CONFIRM
    echo
    if [ -z "$PASSWORD" ]; then
        die "Password must not be empty."
    fi
    if [ "${#PASSWORD}" -lt 8 ]; then
        die "Password must be at least 8 characters (Filebrowser minimum)."
    fi
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        die "Passwords do not match."
    fi
    FILEBROWSER_PASSWORD="$PASSWORD"
fi

# --- Prepare the database (service is stopped to avoid the Bolt-DB lock) ----

say "Preparing Filebrowser database at $HOME/.config/filebrowser"
mkdir -p "$HOME/.config/filebrowser"

if systemctl --user is-active --quiet filebrowser.service 2>/dev/null; then
    say "Stopping filebrowser.service to apply database changes..."
    systemctl --user stop filebrowser.service
fi

FB="$(command -v filebrowser)" || die "filebrowser binary not on PATH after home-manager switch."

if [ ! -f "$DB" ]; then
    say "Database missing; initializing a fresh one"
    "$FB" config init --database "$DB" >/dev/null
else
    say "Database exists"
fi

"$FB" config set --database "$DB" --minimumPasswordLength 8 >/dev/null
"$FB" config set --database "$DB" --tus.chunkSize "$TUS_CHUNK_SIZE" >/dev/null

if ! "$FB" --database "$DB" users ls 2>/dev/null | awk -v u="$USERNAME" '$2==u {found=1} END{exit !found}'; then
    say "Creating admin user '$USERNAME'..."
    "$FB" --database "$DB" users add "$USERNAME" "$FILEBROWSER_PASSWORD" --perm.admin >/dev/null
else
    say "Updating password for user '$USERNAME'..."
    "$FB" --database "$DB" users update "$USERNAME" --password "$FILEBROWSER_PASSWORD" >/dev/null
fi

# --- Start -----------------------------------------------------------------
#
# Enable linger so the user service starts at boot without requiring a
# desktop login session. (The user systemd manager is still started at boot,
# but healthcheck; user services run only with linger enabled. This makes
# filebrowser.service start automatically even for headless/SSH-only boots.)

if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]; then
    say "Enabling linger so filebrowser starts at boot without a login session..."
    sudo loginctl enable-linger "$USER"
fi

say "Starting filebrowser.service..."
systemctl --user start filebrowser.service
systemctl --user enable filebrowser.service >/dev/null 2>&1 || true

# --- Report -----------------------------------------------------------------
sleep 2
if curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -q 200; then
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    cat <<EOF

==> Filebrowser is ready!
    Local:   http://localhost:8080   (user: $USERNAME)
    Network: http://${IP}:8080       (user: $USERNAME)
    Password: set as configured above.
    Quick restart:  systemctl --user restart filebrowser.service
    Logs:           journalctl --user -u filebrowser.service -f
EOF
else
    say "Service started but not serving yet — check: journalctl --user -u filebrowser.service"
    exit 1
fi