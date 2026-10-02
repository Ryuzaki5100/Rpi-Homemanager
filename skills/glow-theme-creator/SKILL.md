---
name: glow-theme-creator
description: Use when the user describes the vibe, mood, or palette of a terminal colorscheme they want for glow (e.g. "warm retro CRT amber", "cold cyberpunk neon", "nord but warmer"). Asks for the theme name (or invents a fitting kebab-case name from the palette when they can't), derives a coherent palette, writes a glamour v2 style JSON to ~/dotfiles/glow/themes/<name>.json, validates it, previews it with glow, and instructs the user to run home-manager switch so glow-set-theme lists it.
---

# glow-theme-creator

Create a custom glow (glamour v2) markdown theme from a user's described vibe, and
add it to the dotfiles theme library so it becomes selectable with `glow-set-theme`.

## When to use

- The user describes a colorscheme mood/vibe they want for glow.
- The user wants a new theme JSON added under `~/dotfiles/glow/themes/`.

## Steps

1. **Gather inputs** with the `question` tool:
   - **Theme name** — kebab-case. Offer two paths: "I'll name it" or "You decide".
   - **Vibe / palette description** — e.g. "warm retro CRT amber", "cold neon cyberpunk", "forest at dusk".
   - **Background** — dark or light.
   If the description is vague, ask 1–2 follow-ups (base hue, accent color, any reference).

2. **Derive a coherent palette** and assign roles:
   `background`, `foreground`, `heading`, `accent`, `muted`, `link`, `code`, `error`,
   plus syntax roles `keyword`, `type`, `function`, `string`, `number`, `operator`.
   Keep foreground/background contrast high; headings/accent brighter than body; muted dimmer.

3. **Map roles to glamour keys** (see schema below). Use hex `"#rrggbb"` for truecolor.
   Start from an existing theme in `~/dotfiles/glow/themes/` as a template — every theme
   is a complete `ansi.StyleConfig` and it is safest to keep all keys present.

4. **Build the code-block syntax palette** as an inline `code_block.chroma` object
   (glamour v2). Map the syntax roles onto the chroma keys listed below. This keeps code
   blocks cohesive with the theme. (The legacy `code_block.theme` string, e.g. `"monokai"`,
   still works but pulls in colors that usually clash with a custom palette.)

5. **Resolve the name**:
   - If the user provided one, sanitize to lowercase kebab-case (letters, digits, single hyphens).
   - If the user deferred, infer a short evocative name from the palette (e.g. `ember-noir`,
     `glacier`, `sakura-dusk`).
   - Check `~/dotfiles/glow/themes/*.json` for collisions; if taken, ask to overwrite or rename.

6. **Write the file** to `~/dotfiles/glow/themes/<name>.json` with the `write` tool.
   Create the directory first if it does not exist (`mkdir -p ~/dotfiles/glow/themes`).

7. **Validate**:
   - `jq . ~/dotfiles/glow/themes/<name>.json` must succeed (valid JSON).
   - Confirm required keys exist: `document`, `heading`, `h1`–`h6`, `code`, `code_block`,
     `link`, `link_text`, `emph`, `strong`, `block_quote`, `list`, `item`, `enumeration`, `hr`.

8. **Preview** (works before any rebuild):
   - If no markdown file is given, write a small sample to `/tmp/glow-theme-preview.md`
     containing a heading, bold/italic, inline code, a fenced code block, a quote, a list,
     a link and a table.
   - Run: `glow -s ~/dotfiles/glow/themes/<name>.json /tmp/glow-theme-preview.md`

9. **Deploy instructions** (do NOT run the rebuild yourself):
   - Tell the user to run: `home-manager switch --flake ~/dotfiles#$(whoami)`
     (or the `rebuild-home-manager` fish alias).
   - After the rebuild, `glow-set-theme` lists the new theme automatically, because
     `modules/glow.nix` regenerates `themes.list` from `glow/themes/*.json`.

10. **Report** the theme path, the preview command, and the rebuild step.

## Glamour v2 style schema

The JSON is unmarshalled into `ansi.StyleConfig` (glow 3.x uses `charm.land/glamour/v2`).

**Top-level keys:** `document`, `block_quote`, `paragraph`, `list`, `heading`,
`h1`, `h2`, `h3`, `h4`, `h5`, `h6`, `text`, `strikethrough`, `emph`, `strong`,
`hr`, `item`, `enumeration`, `task`, `link`, `link_text`, `image`, `image_text`,
`code`, `code_block`, `table`, `definition_list`, `definition_term`,
`definition_description`, `html_block`, `html_span`.

**Primitive attributes:** `block_prefix`, `block_suffix`, `prefix`, `suffix`,
`color`, `background_color`, `underline`, `bold`, `upper`, `lower`, `title`,
`italic`, `crossed_out`, `faint`, `conceal`, `inverse`, `blink`, `format`.

**Block-only attributes:** `indent`, `indent_token`, `margin`.
**`list`:** adds `level_indent` (number).
**`task`:** `ticked`, `unticked` (strings).
**`code_block`:** `theme` (Chroma style name) and/or `chroma` (inline palette object).

**Color values:** hex string `"#rrggbb"` (truecolor) or ANSI index string `"0"`–`"255"`.
**`hr` / `image_text`:** use `format` (e.g. `"\n--------\n"`, `"Image: {{.text}} →"`).

**`code_block.chroma` keys:** `text`, `error`, `comment`, `comment_preproc`,
`keyword`, `keyword_reserved`, `keyword_namespace`, `keyword_type`, `operator`,
`punctuation`, `name`, `name_builtin`, `name_tag`, `name_attribute`, `name_class`,
`name_constant`, `name_decorator`, `name_exception`, `name_function`, `name_other`,
`literal`, `literal_number`, `literal_date`, `literal_string`, `literal_string_escape`,
`generic_deleted`, `generic_emph`, `generic_inserted`, `generic_strong`,
`generic_subheading`, `background`.

## Role → key mapping

| Role | glamour key(s) |
|---|---|
| foreground | `document.color`, `text.color` |
| heading / accent | `heading.color`, `h1`–`h6.color`, `strong.color`, `emph.color` |
| muted | `block_quote.color`, `hr.color`, `h6.color` |
| link | `link.color`, `link_text.color` |
| inline code | `code.color`, `code.background_color` |
| code block | `code_block.color`, `code_block.background_color`, `code_block.chroma.*` |
| list markers | `item.color`, `enumeration.color` |
| error / deleted | `strikethrough.color`, `chroma.error`, `chroma.generic_deleted` |

## Naming heuristics

- Prefer 1–2 words, evocative of the vibe (`ember`, `glacier`, `neon-abyss`).
- Lowercase, hyphens only, no leading/trailing/double hyphens.
- Never collide with an existing file in `~/dotfiles/glow/themes/`.

## Validation checklist

- [ ] JSON parses (`jq .` exits 0)
- [ ] All required keys present, including a `code_block.chroma` palette
- [ ] Name is kebab-case and unique
- [ ] `glow -s <path>` preview renders without error
- [ ] Rebuild instruction given to the user

## Error handling

- Invalid JSON after write → fix and re-validate.
- Name collision → ask to overwrite or rename.
- `glow` preview fails → report the error and keep the JSON (path may still be valid).
- Themes dir missing → create it with `mkdir -p`.

## Tools reference

- `question` — theme name, vibe, background, collision decisions
- `read` / `glob` — inspect existing themes for a template
- `write` — create the theme JSON and sample markdown
- `bash` — `mkdir -p`, `jq` validation, `glow` preview
