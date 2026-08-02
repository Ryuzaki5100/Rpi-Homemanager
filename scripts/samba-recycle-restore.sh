#!/usr/bin/env bash
set -uo pipefail

# samba-recycle-restore.sh — Undo Samba recycle-bin deletes for a share
#
# Usage: samba-recycle-restore.sh <share-root>
#
# 1. Snapshots the current recycle bin to <share-root>/.recycle-backups/<timestamp>
#    so the undo itself is reversible.
# 2. Moves every deleted file/dir back to its original location (the recycle
#    bin uses keeptree, so relative paths map straight back to the share root).
#    Items whose original path still exists are left in the recycle bin.
#
# Handles recycle:versions suffixing (.1, .2, ...): the newest deleted version
# (the unsuffixed name) is restored last, so it ends up in place.

SHARE_ROOT="${1:?Usage: $0 <share-root>}"
RECYCLE="$SHARE_ROOT/.recycle"

if [ ! -d "$RECYCLE" ]; then
    echo "No recycle bin at $RECYCLE — nothing to restore."
    exit 0
fi

if [ ! -w "$SHARE_ROOT" ]; then
    echo "ERROR: $SHARE_ROOT is not writable (is the mount read-only?)."
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$SHARE_ROOT/.recycle-backups/$STAMP"
mkdir -p "$BACKUP_DIR"
cp -a "$RECYCLE"/. "$BACKUP_DIR/" 2>/dev/null
echo "==> Recycle bin snapshot saved to $BACKUP_DIR"

restored=0
skipped=0
declare -A placed=()

while IFS= read -r entry; do
    rel="${entry#"$RECYCLE/"}"
    orig="$(printf '%s' "$rel" | sed -E 's/\.[0-9]+$//')"
    dest="$SHARE_ROOT/$orig"

    if [ -e "$dest" ] && [ -z "${placed[$dest]:-}" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    if [ -e "$dest" ]; then
        rm -rf "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    if ! mv "$entry" "$dest"; then
        echo "    WARN: could not restore $rel"
        continue
    fi
    placed["$dest"]=1
    restored=$((restored + 1))
done < <(find "$RECYCLE" -mindepth 1 | sort -r)

echo "==> Restored $restored item(s) to their original locations."
[ "$skipped" -gt 0 ] && echo "    Skipped $skipped (original still exists; kept in recycle bin)."
