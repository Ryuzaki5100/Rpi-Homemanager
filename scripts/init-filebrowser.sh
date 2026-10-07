#!/usr/bin/env bash
set -euo pipefail

# One-shot reproducible Filebrowser setup.
# - Applies the Home Manager flake (installs filebrowser + the platform service)
# - Interactively sets (or updates) the admin password
# - Ensures DB, min password length, and TUS chunk size are configured
# - Starts the service and prints the access URL
#
# Service manager: systemd user unit on Linux, launchd agent on macOS.
# Idempotent: safe to re-run. Prompts for the password unless
# FILEBROWSER_PASSWORD is already set in the environment.

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DB="$HOME/.config/filebrowser/filebrowser.db"
USERNAME="${FILEBROWSER_USERNAME:-admin}"
TUS_CHUNK_SIZE="${FILEBROWSER_TUS_CHUNK_SIZE:-2147483648}"
LAUNCHD_LABEL="org.nix-community.home.filebrowser"
OS="$(uname -s)"

say() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Ensure Nix + Home Manager from the flake -----------------------------

has_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! has_cmd nix; then
    die "Nix is not installed. Run first: scripts/install-nix.sh"
fi
if [ "$OS" != "Darwin" ] \
    && ! grep -q "^experimental-features = .*nix-command.*flakes" /etc/nix/nix.conf 2>/dev/null; then
    say "Enabling Nix flakes..."
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
fi

say "Applying Home Manager configuration from $DOTFILES"
cd "$DOTFILES"
if has_cmd home-manager; then
    home-manager switch --impure --flake .#$(whoami)
else
    nix run github:nix-community/home-manager -- switch --impure --flake .#$(whoami)
fi

# --- Service control helpers ----------------------------------------------

if [ "$OS" = "Darwin" ]; then
    service_active() { launchctl print "gui/$UID/$LAUNCHD_LABEL" >/dev/null 2>&1; }
    service_stop() { service_active && launchctl bootout "gui/$UID/$LAUNCHD_LABEL" || true; }
    service_start() {
        launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist" 2>/dev/null \
            || launchctl kickstart -k "gui/$UID/$LAUNCHD_LABEL"
    }
else
    service_active() { systemctl --user is-active --quiet filebrowser.service 2>/dev/null; }
    service_stop() { systemctl --user stop filebrowser.service 2>/dev/null || true; }
    service_start() { systemctl --user start filebrowser.service; }
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

if service_active; then
    say "Stopping Filebrowser to apply database changes..."
    service_stop
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

if [ "$OS" = "Darwin" ]; then
    # launchd agents with RunAtLoad start at login; no linger equivalent needed.
    say "Starting Filebrowser agent..."
    service_start
else
    # Enable linger so the user service starts at boot without requiring a
    # desktop login session.
    if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]; then
        say "Enabling linger so filebrowser starts at boot without a login session..."
        sudo loginctl enable-linger "$USER"
    fi
    say "Starting filebrowser.service..."
    service_start
    systemctl --user enable filebrowser.service >/dev/null 2>&1 || true
fi

# --- Report -----------------------------------------------------------------
sleep 2
if curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -q 200; then
    if [ "$OS" = "Darwin" ]; then
        IP="$(ipconfig getifaddr en0 2>/dev/null || echo localhost)"
        RESTART_HINT="launchctl kickstart -k gui/$UID/$LAUNCHD_LABEL"
        LOGS_HINT="log show --predicate 'process == \"filebrowser\"' --last 5m"
    else
        IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
        RESTART_HINT="systemctl --user restart filebrowser.service"
        LOGS_HINT="journalctl --user -u filebrowser.service -f"
    fi
    cat <<EOF

==> Filebrowser is ready!
    Local:   http://localhost:8080   (user: $USERNAME)
    Network: http://${IP}:8080       (user: $USERNAME)
    Password: set as configured above.
    Quick restart:  ${RESTART_HINT}
    Logs:           ${LOGS_HINT}
EOF
else
    say "Service started but not serving yet — check the service logs."
    exit 1
fi
