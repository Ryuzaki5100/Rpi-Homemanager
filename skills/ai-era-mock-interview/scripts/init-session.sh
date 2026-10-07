#!/usr/bin/env bash
# init-session.sh [session_dir]
# Safety gate + scaffold for an ai-era-mock-interview session.
# Allows only an empty directory (or one containing just .git).
set -euo pipefail

SESSION_DIR="${1:-$PWD}"

shopt -s dotglob nullglob
for entry in "$SESSION_DIR"/*; do
  base="$(basename "$entry")"
  if [[ "$base" != ".git" ]]; then
    echo "ERROR: '$SESSION_DIR' is not empty (found '$base')." >&2
    echo "Run the interview in a fresh, empty directory." >&2
    exit 1
  fi
done

mkdir -p "$SESSION_DIR/codebase" "$SESSION_DIR/scratch"
cd "$SESSION_DIR"

if [[ ! -d .git ]]; then
  git init -q
fi

echo "Session initialized at: $SESSION_DIR"
