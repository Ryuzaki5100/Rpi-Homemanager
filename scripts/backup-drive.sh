#!/usr/bin/env bash
set -uo pipefail

# backup-drive.sh — Rotating hardlink snapshot backup of a mount
#
# Usage: backup-drive.sh <source-mount> <backup-root>
#
# Creates <backup-root>/<YYYYMMDD-HHMMSS> as a mirror snapshot of <source>.
# Unchanged files are hardlinked to the previous snapshot (deduplicated), so
# only changed data consumes new space. Keeps the KEEP newest snapshots.
#
# Env: KEEP=5  number of snapshots to retain (default 5)

SRC="${1:?Usage: $0 <source-mount> <backup-root>}"
BKROOT="${2:?Usage: $0 <source-mount> <backup-root>}"
KEEP="${KEEP:-5}"

if [ ! -d "$SRC" ]; then
    echo "ERROR: source $SRC does not exist."
    exit 1
fi
if [ ! -d "$BKROOT" ]; then
    echo "ERROR: backup root $BKROOT does not exist."
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
SNAP="$BKROOT/$STAMP"
PREV="$(ls -1d "$BKROOT"/*/ 2>/dev/null | tail -1)"

LINK_DEST=()
if [ -n "$PREV" ]; then
    LINK_DEST=(--link-dest="$PREV")
fi

mkdir -p "$SNAP"
rsync -a --delete "${LINK_DEST[@]}" "$SRC"/ "$SNAP"/
echo "==> Backup of $SRC -> $SNAP"

while [ "$(ls -1d "$BKROOT"/*/ 2>/dev/null | wc -l)" -gt "$KEEP" ]; do
    OLDEST="$(ls -1dt "$BKROOT"/*/ 2>/dev/null | tail -1)"
    rm -rf "$OLDEST"
    echo "    Pruned old snapshot: $OLDEST"
done

echo "    Retained snapshots:"
ls -1dt "$BKROOT"/*/ 2>/dev/null | head -n "$KEEP" | sed 's/^/      /'
