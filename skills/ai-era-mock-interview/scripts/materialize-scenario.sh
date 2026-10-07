#!/usr/bin/env bash
# materialize-scenario.sh <scenario-name> [session_dir]
# Copies a curated scenario's template into <session_dir>/codebase and
# prints the scenario's ticket.md path for the interviewer to read.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO="${1:?usage: materialize-scenario.sh <scenario-name> [session_dir]}"
SESSION_DIR="${2:-$PWD}"

SRC="$SKILL_DIR/scenarios/$SCENARIO"
if [[ ! -d "$SRC/template" ]]; then
  echo "ERROR: no such scenario '$SCENARIO'." >&2
  echo "Available:" >&2
  ls -1 "$SKILL_DIR/scenarios" >&2
  exit 1
fi

mkdir -p "$SESSION_DIR/codebase"
cp -r "$SRC/template/." "$SESSION_DIR/codebase/"

echo "Materialized '$SCENARIO' into $SESSION_DIR/codebase"
echo "Ticket source (interviewer only): $SRC/ticket.md"
echo "Hidden solution (interviewer only): $SRC/solution.md"
