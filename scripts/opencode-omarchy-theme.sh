#!/usr/bin/env bash
# Generate an opencode theme from the active Omarchy palette.
#
# Reads  : ~/.local/state/omarchy/current/theme/colors.toml
# Writes : ~/.config/opencode/themes/omarchy.json
#
# Invoked by the theme-set hook (after every `omarchy theme set`) and by the
# fish `opencode` wrapper (before launch), so the TUI always matches the
# desktop theme.

set -euo pipefail

COLORS_FILE="${OMARCHY_COLORS_FILE:-$HOME/.local/state/omarchy/current/theme/colors.toml}"
OUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/themes"
OUT_FILE="$OUT_DIR/omarchy.json"

[[ -f $COLORS_FILE ]] || { echo "opencode-omarchy-theme: missing $COLORS_FILE" >&2; exit 0; }

declare -A C=()
while IFS= read -r line; do
  [[ $line =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"(#[0-9A-Fa-f]{3,8})\" ]] || continue
  C["${BASH_REMATCH[1],,}"]="${BASH_REMATCH[2]}"
done <"$COLORS_FILE"

# get <key> [fallback-key|#hex]... -- first key present in colors.toml wins,
# a literal #hex short-circuits, otherwise fall back to the foreground.
get() {
  local key="$1"
  shift
  if [[ -n ${C[$key]:-} ]]; then
    printf '%s' "${C[$key]}"
    return
  fi
  local fb
  for fb in "$@"; do
    if [[ $fb == \#* ]]; then
      printf '%s' "$fb"
      return
    fi
    if [[ -n ${C[$fb]:-} ]]; then
      printf '%s' "${C[$fb]}"
      return
    fi
  done
  printf '%s' "${C[foreground]:-#ffffff}"
}

# mix <base-hex> <overlay-hex> <amount 0..1>
mix() {
  local base="${1#\#}" over="${2#\#}" amount="$3"
  awk -v a="$base" -v b="$over" -v t="$amount" '
    function hv(c) { return index("0123456789abcdef", tolower(c)) - 1 }
    function pair(s, i) { return hv(substr(s, i, 1)) * 16 + hv(substr(s, i + 1, 1)) }
    BEGIN {
      ar = pair(a, 1); ag = pair(a, 3); ab = pair(a, 5)
      br = pair(b, 1); bg = pair(b, 3); bb = pair(b, 5)
      printf "#%02x%02x%02x", int(ar + (br - ar) * t + 0.5), int(ag + (bg - ag) * t + 0.5), int(ab + (bb - ab) * t + 0.5)
    }'
}

bg=$(get background)
fg=$(get foreground)
accent=$(get accent blue color4 "$fg")
muted=$(get muted dark_foreground color8 "$fg")
dark_bg=$(get dark_background darker_background background "$bg")
darker_bg=$(get darker_background dark_background background "$bg")
lighter_bg=$(get lighter_background selection dark_background background "$bg")
selection=$(get selection lighter_background dark_background "$bg")
bright_fg=$(get bright_foreground foreground color15 "$fg")

red=$(get red color1 "#ff5555")
bright_red=$(get bright_red red color9 "$red")
green=$(get green color2 "#50fa7b")
bright_green=$(get bright_green green color10 "$green")
yellow=$(get yellow color3 "#f1fa8c")
orange=$(get orange yellow color3 "$yellow")
blue=$(get blue color4 accent "$accent")
magenta=$(get magenta color5 accent "$accent")
cyan=$(get cyan color6 blue "$blue")

mkdir -p "$OUT_DIR"
tmp="$(mktemp "$OUT_DIR/.omarchy.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<JSON
{
  "\$schema": "https://opencode.ai/theme.json",
  "theme": {
    "primary": "$accent",
    "secondary": "$blue",
    "accent": "$cyan",
    "error": "$red",
    "warning": "$yellow",
    "success": "$green",
    "info": "$blue",
    "text": "$fg",
    "textMuted": "$muted",
    "selectedListItemText": "$bg",
    "background": "$bg",
    "backgroundPanel": "$dark_bg",
    "backgroundElement": "$lighter_bg",
    "backgroundMenu": "$lighter_bg",
    "border": "$lighter_bg",
    "borderActive": "$accent",
    "borderSubtle": "$darker_bg",
    "diffAdded": "$green",
    "diffRemoved": "$red",
    "diffContext": "$muted",
    "diffHunkHeader": "$cyan",
    "diffHighlightAdded": "$bright_green",
    "diffHighlightRemoved": "$bright_red",
    "diffAddedBg": "$(mix "$bg" "$green" 0.15)",
    "diffRemovedBg": "$(mix "$bg" "$red" 0.15)",
    "diffContextBg": "$dark_bg",
    "diffLineNumber": "$muted",
    "diffAddedLineNumberBg": "$(mix "$bg" "$green" 0.10)",
    "diffRemovedLineNumberBg": "$(mix "$bg" "$red" 0.10)",
    "markdownText": "$fg",
    "markdownHeading": "$accent",
    "markdownLink": "$blue",
    "markdownLinkText": "$cyan",
    "markdownCode": "$green",
    "markdownBlockQuote": "$muted",
    "markdownEmph": "$orange",
    "markdownStrong": "$yellow",
    "markdownHorizontalRule": "$muted",
    "markdownListItem": "$accent",
    "markdownListEnumeration": "$cyan",
    "markdownImage": "$blue",
    "markdownImageText": "$cyan",
    "markdownCodeBlock": "$fg",
    "syntaxComment": "$muted",
    "syntaxKeyword": "$magenta",
    "syntaxFunction": "$blue",
    "syntaxVariable": "$cyan",
    "syntaxString": "$green",
    "syntaxNumber": "$orange",
    "syntaxType": "$yellow",
    "syntaxOperator": "$magenta",
    "syntaxPunctuation": "$fg",
    "thinkingOpacity": 0.6
  }
}
JSON

mv "$tmp" "$OUT_FILE"
chmod 644 "$OUT_FILE"
trap - EXIT
echo "opencode-omarchy-theme: wrote $OUT_FILE"
