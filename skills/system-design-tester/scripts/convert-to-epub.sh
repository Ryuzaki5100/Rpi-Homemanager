#!/usr/bin/env bash
# Convert markdown to EPUB using pandoc
# Usage: convert-to-epub.sh <input.md> <output.epub> <title> [author]

set -euo pipefail

INPUT="${1:-}"
OUTPUT="${2:-}"
TITLE="${3:-}"
AUTHOR="${4:-System Design Tester}"

if [[ -z "$INPUT" || -z "$OUTPUT" || -z "$TITLE" ]]; then
    echo "Usage: $0 <input.md> <output.epub> <title> [author]"
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc not found. Install with: nix-shell -p pandoc  OR  apt-get install pandoc"
    exit 1
fi

pandoc "$INPUT" -o "$OUTPUT" \
    --metadata title="$TITLE" \
    --metadata author="$AUTHOR" \
    --toc --toc-depth=3 2>/dev/null || true

if [[ -f "$OUTPUT" && -s "$OUTPUT" ]]; then
    echo "Created: $OUTPUT"
else
    echo "Warning: EPUB creation may have failed for $OUTPUT"
    exit 1
fi
