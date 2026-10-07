#!/usr/bin/env bash
# build-epubs.sh — convert the ~/interview-prep markdown tree into EPUB books.
#
# Produces, in ~/interview-prep-epub/:
#   - one EPUB per directory that directly contains markdown (mirrors the tree)
#   - one master EPUB containing every markdown file
#
# Only tools from the home-manager profile are used (pandoc, epubcheck,
# dejavu_fonts, python3). Nothing is installed or downloaded here, and the
# source tree is never modified (preprocessing happens on staged copies).
#
# Usage: build-epubs.sh [SRC] [OUT]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREPROCESS="$SCRIPT_DIR/epub-preprocess.py"

SRC="${1:-${SRC:-$HOME/interview-prep}}"
OUT="${2:-${OUT:-$HOME/interview-prep-epub}}"
STAGE="$OUT/.staging"
AUTHOR="${AUTHOR:-Atharva}"
LANG_CODE="${LANG_CODE:-en}"
TITLE_ROOT="Interview Prep — Complete"

die() { echo "error: $*" >&2; exit 1; }

[ -d "$SRC" ] || die "source dir not found: $SRC"
[ -f "$PREPROCESS" ] || die "preprocessor not found: $PREPROCESS"
command -v pandoc >/dev/null 2>&1 || die "pandoc not on PATH (declare it via home-manager)"
command -v python3 >/dev/null 2>&1 || die "python3 not on PATH (declare it via home-manager)"

FONT_FILE="$(fc-match -f '%{file}\n' 'DejaVu Sans Mono' 2>/dev/null | head -n1 || true)"
[ -n "${FONT_FILE:-}" ] && [ -f "$FONT_FILE" ] || die "DejaVu Sans Mono not found via fc-match"

HAVE_EPUBCHECK=0
command -v epubcheck >/dev/null 2>&1 && HAVE_EPUBCHECK=1

echo "==> source : $SRC"
echo "==> output : $OUT"
echo "==> font   : $FONT_FILE"
[ "$HAVE_EPUBCHECK" -eq 1 ] && echo "==> epubcheck: yes" || echo "==> epubcheck: NOT FOUND (skipping validation)"

rm -rf "$STAGE"
mkdir -p "$OUT" "$OUT/fonts" "$STAGE"
cp -f "$FONT_FILE" "$OUT/fonts/DejaVuSansMono.ttf"

# ---------------------------------------------------------------- stylesheet
cat > "$OUT/epub.css" <<'CSS'
@font-face {
  font-family: 'DejaVuSansMono';
  font-style: normal;
  font-weight: normal;
  src: url('../fonts/DejaVuSansMono.ttf') format('truetype');
}
body { font-family: Georgia, 'Times New Roman', serif; line-height: 1.5; }
h1, h2, h3, h4 { line-height: 1.2; }
code, pre, kbd, samp { font-family: 'DejaVuSansMono', 'Courier New', monospace; }
pre {
  font-size: 0.78em;
  line-height: 1.35;
  white-space: pre-wrap;
  overflow-wrap: break-word;
  word-break: break-word;
  background: #f6f8fa;
  border-radius: 4px;
  padding: 0.55em 0.7em;
}
pre code { white-space: pre-wrap; }
/* ASCII / box-drawing diagrams: no wrapping, small font so wide art fits */
pre.diagram, pre.diagram code {
  font-size: 0.5em;
  line-height: 1.2;
  white-space: pre;
  overflow-wrap: normal;
  word-break: normal;
}
table { border-collapse: collapse; font-size: 0.82em; width: 100%; margin: 0.6em 0; }
th, td { border: 1px solid #bbb; padding: 0.3em 0.5em; text-align: left; vertical-align: top; }
th { background: #f0f0f0; }
blockquote { border-left: 3px solid #999; margin: 0.6em 0; padding: 0 0.9em; color: #333; }
img { max-width: 100%; height: auto; }
CSS

# ------------------------------------------------------------- book discovery
# Directories that directly contain markdown, excluding archives.
list_book_dirs() {
  cd "$SRC"
  find . -path ./.git -prune -o -type d -print \
    | sed 's|^\./||' \
    | grep -v -E '(^|/)(99-archive|old-notes)(/|$)' \
    | grep -v '^$' \
    | while IFS= read -r d; do
        n=$(find "$d" -maxdepth 1 -name '*.md' -type f | wc -l)
        [ "$n" -gt 0 ] && echo "$d"
      done \
    | sort
}

# --------------------------------------------------------------- per-dir books
build_book() {
  local dir="$1" title="$2" out="$3"
  local stage_dir="$STAGE/$(echo "$dir" | tr '/' '_')"
  local avail="$stage_dir/.available.txt"
  local -a inputs=()
  mkdir -p "$stage_dir"

  # available link targets = files in this book (root-relative)
  : > "$avail"
  while IFS= read -r f; do
    echo "${f#"$SRC"/}" >> "$avail"
  done < <(find "$SRC/$dir" -maxdepth 1 -name '*.md' -type f | sort)

  while IFS= read -r f; do
    local base out_md
    base="$(basename "$f")"
    out_md="$stage_dir/$base"
    python3 "$PREPROCESS" --root "$SRC" --file "$f" --available "$avail" > "$out_md"
    inputs+=("$out_md")
  done < <(find "$SRC/$dir" -maxdepth 1 -name '*.md' -type f | sort)

  [ "${#inputs[@]}" -gt 0 ] || return 0

  mkdir -p "$(dirname "$out")"
  pandoc "${inputs[@]}" \
    -o "$out" \
    --toc --toc-depth=3 \
    --highlight-style=tango \
    --css="$OUT/epub.css" \
    --epub-embed-font="$FONT_FILE" \
    --metadata title="$title" \
    --metadata author="$AUTHOR" \
    --metadata lang="$LANG_CODE"

  echo "    book: ${out#"$OUT"/}  (${#inputs[@]} files)"
}

echo "==> building per-directory books"
count=0
while IFS= read -r d; do
  [ "$d" = "." ] && continue
  name="$(basename "$d")"
  build_book "$d" "$name" "$OUT/$d/$name.epub"
  count=$((count + 1))
done < <(list_book_dirs)
echo "==> $count books built"

# ------------------------------------------------------------------- master
echo "==> building master book"
master_stage="$STAGE/_master"
mkdir -p "$master_stage"
master_avail="$master_stage/.available.txt"
master_inputs=()

# available = every non-archive markdown file, root-relative
: > "$master_avail"
while IFS= read -r f; do
  echo "${f#"$SRC"/}" >> "$master_avail"
done < <(
  find "$SRC" -path "$SRC/.git" -prune -o -name '*.md' -type f -print \
    | grep -v -E '/(99-archive|old-notes)/' | sort
)

add_master() {
  local f="$1" rel out_md
  rel="${f#"$SRC"/}"
  out_md="$master_stage/$(echo "$rel" | tr '/' '__')"
  python3 "$PREPROCESS" --root "$SRC" --file "$f" --available "$master_avail" > "$out_md"
  master_inputs+=("$out_md")
}
if [ -f "$SRC/README.md" ]; then add_master "$SRC/README.md"; fi
while IFS= read -r f; do
  [ "$f" = "$SRC/README.md" ] && continue
  add_master "$f"
done < <(
  find "$SRC" -path "$SRC/.git" -prune -o -name '*.md' -type f -print \
    | grep -v -E '/(99-archive|old-notes)/' | sort
)

pandoc "${master_inputs[@]}" \
  -o "$OUT/interview-prep.epub" \
  --toc --toc-depth=2 \
  --highlight-style=tango \
  --css="$OUT/epub.css" \
  --epub-embed-font="$FONT_FILE" \
  --metadata title="$TITLE_ROOT" \
  --metadata author="$AUTHOR" \
  --metadata lang="$LANG_CODE"
echo "    master: interview-prep.epub  (${#master_inputs[@]} files)"

# --------------------------------------------------------------- validation
if [ "$HAVE_EPUBCHECK" -eq 1 ]; then
  echo "==> validating with epubcheck"
  fail=0; total=0
  while IFS= read -r ep; do
    total=$((total + 1))
    if ! epubcheck "$ep" >/tmp/epubcheck.out 2>&1; then
      echo "    FAIL: ${ep#"$OUT"/}"
      grep -E 'ERROR|FATAL' /tmp/epubcheck.out | head -8 | sed 's/^/      /'
      fail=$((fail + 1))
    fi
  done < <(find "$OUT" -name '*.epub' | sort)
  echo "==> epubcheck: $((total - fail))/$total valid"
  [ "$fail" -eq 0 ] || die "$fail EPUB(s) failed validation"
else
  echo "==> skipping epubcheck (not installed)"
fi

rm -rf "$STAGE"
echo "==> done. Output in $OUT"
