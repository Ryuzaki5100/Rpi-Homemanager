---
name: content-to-diagram
description: Turn a Markdown file, pasted explanation, notes, README, article, transcript, PDF, or any readable text document into a validated, interactive Archify HTML diagram. Use when the user supplies content and asks to visualize, diagram, map, or explain it as an architecture, workflow, sequence, data flow, lifecycle, ERD, class, tree, timeline, or waterfall. Always asks which diagram type to use; defaults to one <slug>.html file in the invocation directory and leaves no sidecar files beside it.
---

# content-to-diagram

Read the supplied content, ask which diagram type the user wants, author an Archify
candidate, and deliver exactly one standalone interactive HTML file.

## Step 0 — Read the guide first (mandatory)

Read the full workflow before acting:

```
read <skill-base-dir>/GUIDE.md
```

## Core rules (always apply)

1. **Read the actual content first.** Preserve its names, facts, directions, conditions, and
   order. Never invent data, dates, amounts, or relationships. Label illustrative values.
2. **Always ask the user which diagram type to use** before authoring, preferring the
   `question` tool. Recommend the best fit first, but let the user choose. Never silently pick
   a type.
3. **Default output is `./<slug>.html` in the invocation directory.** Honor a user-supplied
   path. Ask only when the target already exists, the directory is unwritable, or the request
   is genuinely ambiguous.
4. **Use the `archify` CLI from `PATH`.** Never hand-write HTML, never install or update
   Archify, and never call a remote rendering service.
5. **Read Archify's authoring contract before writing the candidate:** `$ARCHIFY_ROOT/SKILL.md`,
   `$ARCHIFY_ROOT/references/authoring-defaults.md`, and the selected type's schema and
   example. If `$ARCHIFY_ROOT` is unset, derive it from the CLI path:
   `ARCHIFY_ROOT="$(dirname "$(dirname "$(command -v archify)")")/share/archify"`.
   Archify's rules are authoritative; this skill only routes to them.
6. **Use one disposable temp workspace outside the output directory.** Keep `candidate.json`
   and the temporary `diagram.html` there. Set `meta.output` to `"diagram.html"` inside that
   workspace. Never create a candidate folder, receipts, or temporary files beside the final
   HTML.
7. **Deliver with the clean pipeline:** `archify validate` → `archify render` → `archify check`
   → move only the checked `diagram.html` to the final path → delete the temp workspace. Do not
   run `finalize` or `deliver` by default; both write sidecar files.
8. **The output directory must contain only the final HTML.** Never leave `.archify/`,
   `*.delivery.json`, `*.finalize.json`, `*.finalize-summary.json`, `*.browser-check.json`,
   candidate JSON, or any other byproduct there. Ask before overwriting an existing target.
9. **Reply with a clickable absolute link and at most 1–2 sentences.** State that automated
   schema and artifact checks passed; do not claim visual review or delivery provenance.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Run intake, type prompt, temp-workspace handling, clean delivery, repair, or reply format | `GUIDE.md` | Full wrapper workflow and rules |

## Runtime references (installed Archify package)

- `$ARCHIFY_ROOT/SKILL.md` — authoritative authoring workflow and Type router.
- `$ARCHIFY_ROOT/references/authoring-defaults.md` — layout, presentation, and schema defaults.
- `$ARCHIFY_ROOT/schemas/<type>.schema.json` — schema for the chosen diagram type.
- `$ARCHIFY_ROOT/examples/<mode>.json` — the showcase example for the chosen type.
- `$ARCHIFY_ROOT/references/authoring-contract.md` — validation, geometry, and layout repair.
- `$ARCHIFY_ROOT/references/delivery-contract.md` — only if the user explicitly asks for
  `deliver`/`finalize` receipts; those commands create sidecars.

## Workflow

1. **Intake.** Accept a file path or pasted text; read it and build a structural outline.
   Ask one clarifying question if the content is too vague to diagram.
2. **Ask the type.** Present the ten Archify diagram types, recommended first, and wait for
   the answer. If the user says "you choose", infer from the content.
3. **Resolve the CLI.** Run `command -v archify`; if `$ARCHIFY_ROOT` is unset or lacks
   `SKILL.md`, derive it as `"$(dirname "$(dirname "$(command -v archify)")")/share/archify"`.
   If either is still missing, stop and tell the user how to fix it; do not install anything.
4. **Read the authoring files.** Read Archify's `SKILL.md`, authoring defaults, and the
   selected type's schema and example before drafting.
5. **Create the temp workspace and choose the output.** Default to `<slug>.html` in the
   invocation directory. Create `${TMPDIR:-/tmp}/content-to-diagram-<slug>-<timestamp>/` for
   the candidate and temporary render. Confirm overwrites before the final move.
6. **Author the candidate.** Write `candidate.json` in the temp workspace with
   `meta.output: "diagram.html"`, `meta.title`, `meta.locale`, and `meta.quality_profile`
   (`showcase` by default, `standard` only when the user asks for a dense diagram).
7. **Validate and render.** From the temp workspace run `archify validate`, `archify render`
   to `diagram.html`, then `archify check diagram.html`.
8. **Repair and clean up.** Repair the candidate in the temp workspace if needed (at most two
   focused rounds per persistent issue). On success, move only `diagram.html` to the final
   path and delete the workspace. Delete the workspace before replying even on failure.
9. **Reply.** Link the HTML with its absolute path and state the key takeaway plus any
   disclosures.

## Output location and deployment

The skill lives at `~/dotfiles/skills/content-to-diagram/` and is deployed by home-manager to
`~/.config/opencode/skills/content-to-diagram/`. The `archify` CLI and its `$ARCHIFY_ROOT`
come from `~/dotfiles/pkgs/archify.nix`. Deploy with:

```bash
home-manager switch --impure --flake ~/dotfiles#$(whoami)
```

Generated diagrams default to the invocation directory. All intermediate files stay in the
temp workspace; only the final HTML is written to the output directory.

## Tools

`read` (input content, Archify schemas/examples), `write`/`edit` (candidate JSON in the temp
workspace), `bash` (run `archify`, move the HTML, clean up), `glob`/`grep` (locate input files
or Archify examples), `question` (diagram type and path decisions).
