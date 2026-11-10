#!/usr/bin/env bash
# compile_resume.sh — render one resume .tex to pdfs/<mirrored-path>.pdf and verify it.
#
# Usage:
#   compile_resume.sh <tex-file> [repo-root]
#
# Examples:
#   compile_resume.sh ~/job-search/my_resumes/google/google_software_engineer.tex
#   compile_resume.sh ./stripe/stripe_software_engineer_new_grad.tex
#
# Layout contract: a .tex at <repo>/<a>/<b>/<name>.tex produces <repo>/pdfs/<a>/<b>/<name>.pdf.
# A root-level .tex produces <repo>/pdfs/<name>.pdf.
#
# Exit codes: 0 built + verified, 1 build failed, 2 page-count/size warning (PDF still written),
#             3 usage or missing toolchain.
#
# Prints a single JSON object on stdout. Compiler output goes to stderr.

set -euo pipefail

REPO_DEFAULT="${HOME}/job-search/my_resumes"
TEX=""
REPO="$REPO_DEFAULT"

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 3
fi

TEX="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[[ -f "$TEX" ]] || { echo "no such file: $1" >&2; exit 3; }
[[ $# -ge 2 ]] && REPO="$(cd "$2" && pwd)"

TEX_DIR="$(dirname "$TEX")"
TEX_STEM="$(basename "$TEX" .tex)"

# Relative directory of the .tex inside the repo, used to mirror the tree.
REL_DIR=""
if [[ "$TEX_DIR" == "$REPO" ]]; then
  REL_DIR=""
elif [[ "$TEX_DIR" == "$REPO"/* ]]; then
  REL_DIR="${TEX_DIR#"$REPO"/}"
else
  # A .tex outside the repo still gets an output folder named after its directory.
  REL_DIR="$(basename "$TEX_DIR")"
fi

OUT_DIR="$REPO/pdfs${REL_DIR:+/$REL_DIR}"
OUT_PDF="$OUT_DIR/$TEX_STEM.pdf"
mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_pdflatex() {
  if command -v pdflatex >/dev/null 2>&1; then
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error \
      -output-directory="$TMP_DIR" "$@"
  elif command -v nix >/dev/null 2>&1; then
    nix shell --impure --expr '
      let p = import <nixpkgs> {};
      in p.texlive.combine {
        inherit (p.texlive)
          scheme-basic enumitem titlesec geometry hyperref ec cm-super;
      }' --command pdflatex -interaction=nonstopmode -halt-on-error -file-line-error \
      -output-directory="$TMP_DIR" "$@"
  else
    echo "pdflatex not found and nix unavailable" >&2
    exit 3
  fi
}

# Two passes so hyperref/refs settle.
for pass in 1 2; do
  if ! ( cd "$TEX_DIR" && run_pdflatex "$(basename "$TEX")" ) \
      >"$TMP_DIR/stdout.$pass" 2>&1; then
    echo "--- pdflatex pass $pass failed ---" >&2
    tail -40 "$TMP_DIR/stdout.$pass" >&2
    if [[ -f "$TMP_DIR/$TEX_STEM.log" ]]; then
      grep -E '^(!|.*:[0-9]+:)' "$TMP_DIR/$TEX_STEM.log" >&2 || true
    fi
    printf '{"tex":"%s","pdf":null,"ok":false,"stage":"pdflatex","error":"pass %s failed"}\n' \
      "$TEX" "$pass"
    exit 1
  fi
done

BUILT="$TMP_DIR/$TEX_STEM.pdf"
if [[ ! -f "$BUILT" ]]; then
  printf '{"tex":"%s","pdf":null,"ok":false,"stage":"pdflatex","error":"no pdf produced"}\n' "$TEX"
  exit 1
fi

mv -f "$BUILT" "$OUT_PDF"

PAGES="unknown"
PAGE_SIZE="unknown"
STATUS="ok"
if command -v pdfinfo >/dev/null 2>&1; then
  INFO="$(pdfinfo "$OUT_PDF" 2>/dev/null || true)"
  PAGES="$(printf '%s\n' "$INFO" | sed -n 's/^Pages:[[:space:]]*//p')"
  PAGE_SIZE="$(printf '%s\n' "$INFO" | sed -n 's/^Page size:[[:space:]]*//p')"
  if [[ "$PAGES" != "1" ]]; then
    STATUS="page_count_${PAGES:-unknown}"
  fi
  case "$PAGE_SIZE" in
    *A4*|*595*) ;;
    *) [[ "$STATUS" == "ok" ]] && STATUS="non_a4" ;;
  esac
fi

TEXT_CHARS="0"
if command -v pdftotext >/dev/null 2>&1; then
  TEXT_CHARS="$(pdftotext "$OUT_PDF" - 2>/dev/null | tr -d '[:space:]' | wc -c | tr -d ' ')"
  if [[ "$TEXT_CHARS" -lt 200 ]]; then
    [[ "$STATUS" == "ok" ]] && STATUS="text_extraction_thin"
  fi
fi

printf '{"tex":"%s","pdf":"%s","pages":"%s","page_size":"%s","text_chars":"%s","status":"%s","ok":%s}\n' \
  "$TEX" "$OUT_PDF" "$PAGES" "$PAGE_SIZE" "$TEXT_CHARS" "$STATUS" \
  "$([[ "$STATUS" == "ok" ]] && echo true || echo false)"

[[ "$STATUS" == "ok" ]] && exit 0 || exit 2
