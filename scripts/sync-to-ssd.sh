#!/usr/bin/env bash
set -euo pipefail

# sync-to-ssd.sh — Sync Immich albums to an external drive (no API key needed)
#
# Usage: sync-to-ssd.sh <destination-path>
#
# Queries the Immich PostgreSQL database directly via Docker.
# Immich must be running.

DEST="${1:?Usage: $0 <destination-path>}"
LIBRARY="${HOME}/immich/library"

psql_run() {
    echo "$1" | sg docker -c "docker exec -i immich_postgres psql -U postgres -d immich -t -A"
}

print_progress() {
    local current=$1 total=$2 filename=$3
    local pct=0 bar="" width=40
    if [ "$total" -gt 0 ]; then
        pct=$((current * 100 / total))
    fi
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    bar=$(printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true)
    bar+=$(printf '%0.s░' $(seq 1 $empty 2>/dev/null) || true)
    printf "\r  [%s] %3d%% (%d/%d) %s" "$bar" "$pct" "$current" "$total" "$filename"
}

mkdir -p "$DEST"

echo "==> Fetching albums..."
ALBUMS=$(psql_run "SELECT id, \"albumName\" FROM album WHERE \"deletedAt\" IS NULL ORDER BY \"albumName\";")
ALBUM_COUNT=$(echo "$ALBUMS" | grep -c . || true)
echo "    Found ${ALBUM_COUNT} album(s)"

if [ "$ALBUM_COUNT" -eq 0 ]; then
    echo "    No albums found. Create some in the Immich web UI first."
    exit 0
fi

# --- Phase 1: Count total assets ---
echo ""
echo "==> Counting total assets..."
TOTAL=0
declare -A ALBUM_COUNTS

while IFS='|' read -r ALBUM_ID ALBUM_NAME; do
    [ -z "$ALBUM_ID" ] && continue
    COUNT=$(psql_run "SELECT COUNT(*) FROM album_asset WHERE \"albumId\" = '${ALBUM_ID}'::uuid;")
    COUNT=${COUNT:-0}
    ALBUM_COUNTS["$ALBUM_ID"]=$COUNT
    TOTAL=$((TOTAL + COUNT))
done <<< "$ALBUMS"

echo "    Total: ${TOTAL} files across ${ALBUM_COUNT} album(s)"

if [ "$TOTAL" -eq 0 ]; then
    echo "    Nothing to sync."
    exit 0
fi

# --- Phase 2: Sync files with progress ---
echo ""
echo "==> Syncing..."
COPIED=0
SKIPPED=0
ERRORS=0

while IFS='|' read -r ALBUM_ID ALBUM_NAME; do
    [ -z "$ALBUM_ID" ] && continue

    ALBUM_TOTAL=${ALBUM_COUNTS["$ALBUM_ID"]:-0}
    [ "$ALBUM_TOTAL" -eq 0 ] && continue

    # Sanitize album name for filesystem
    SAFE_NAME=$(echo "$ALBUM_NAME" | sed 's/[\/\\:*?"<>|]/_/g')
    ALBUM_DIR="${DEST}/${SAFE_NAME}"
    mkdir -p "$ALBUM_DIR"

    echo ""
    echo "  Album: ${ALBUM_NAME} (${ALBUM_TOTAL} files)"

    # Get all assets in this album
    ASSETS=$(psql_run "
        SELECT a.\"originalPath\", a.\"originalFileName\"
        FROM asset a
        JOIN album_asset aa ON a.id = aa.\"assetId\"
        WHERE aa.\"albumId\" = '${ALBUM_ID}'::uuid
        ORDER BY a.\"fileCreatedAt\";
    ")

    ALBUM_DONE=0
    while IFS='|' read -r ORIG_PATH FILENAME; do
        [ -z "$ORIG_PATH" ] && continue

        # Convert container path to host path
        HOST_PATH="${LIBRARY}${ORIG_PATH#/data}"

        DEST_FILE="${ALBUM_DIR}/${FILENAME}"

        # Skip if already synced
        if [ -f "$DEST_FILE" ]; then
            SKIPPED=$((SKIPPED + 1))
            ALBUM_DONE=$((ALBUM_DONE + 1))
            COPIED=$((COPIED + 1))
            print_progress "$COPIED" "$TOTAL" "(cached)"
            continue
        fi

        if [ ! -f "$HOST_PATH" ]; then
            ALBUM_DONE=$((ALBUM_DONE + 1))
            COPIED=$((COPIED + 1))
            print_progress "$COPIED" "$TOTAL" "[MISS] ${FILENAME}"
            continue
        fi

        # Handle duplicate filenames
        if [ -f "$DEST_FILE" ]; then
            BASE="${FILENAME%.*}"
            EXT="${FILENAME##*.}"
            COUNTER=2
            while [ -f "${ALBUM_DIR}/${BASE}_${COUNTER}.${EXT}" ]; do
                COUNTER=$((COUNTER + 1))
            done
            DEST_FILE="${ALBUM_DIR}/${BASE}_${COUNTER}.${EXT}"
        fi

        if ! cp "$HOST_PATH" "$DEST_FILE" 2>/dev/null; then
            ALBUM_DONE=$((ALBUM_DONE + 1))
            COPIED=$((COPIED + 1))
            ERRORS=$((ERRORS + 1))
            print_progress "$COPIED" "$TOTAL" "[ERR] ${FILENAME}"
            continue
        fi
        COPIED=$((COPIED + 1))
        ALBUM_DONE=$((ALBUM_DONE + 1))
        print_progress "$COPIED" "$TOTAL" "${FILENAME}"
    done <<< "$ASSETS"

    echo ""
    echo "    ${ALBUM_DONE} files → ${ALBUM_DIR}"

done <<< "$ALBUMS"

echo ""
echo ""
echo "==> Done!"
echo "    Synced:   ${COPIED} files"
echo "    Cached:   ${SKIPPED} (already existed)"
if [ "$ERRORS" -gt 0 ]; then
    echo "    Errors:   ${ERRORS} (I/O or permission issues)"
fi
echo "    Location: ${DEST}"
