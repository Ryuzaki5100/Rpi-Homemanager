# content-to-diagram — wrapper workflow

This guide covers the parts that are specific to turning supplied content into an Archify
diagram. Archify itself owns the authoring contract, schemas, layout rules, and repair
semantics; read its files from `$ARCHIFY_ROOT` when this guide points there.

The output contract is strict: **one HTML file is written to the output directory, and nothing
else.** Candidate JSON, renders, receipts, and other intermediates live in a disposable
workspace outside that directory.

## §1 Intake and extraction

### Accepted inputs

- Pasted text in the conversation.
- A path to a readable file: Markdown, plain text, reStructuredText, AsciiDoc, HTML, JSON,
  YAML, CSV, source code, or a PDF.
- The Read tool can open text files, images, and PDFs. For an unsupported binary format, ask
  the user to paste the content or convert it to text.
- If the user supplies several files, ask which one to diagram or whether to combine them.

### Read for structure, not prose

Read the content and build an outline before choosing anything. Extract only what the diagram
needs:

- **Subject and purpose** — what the content is about and what the reader should understand.
- **Actors and components** — people, services, systems, stores, modules, roles, or entities.
- **Order and behavior** — steps, calls, events, transitions, retries, branches, and conditions.
- **Relationships** — direction, protocol, ownership, dependency, containment, cardinality.
- **Boundaries** — trust zones, networks, teams, runtimes, persistence, or other real isolation.
- **Data and values** — sources, transforms, stores, outputs, and any named fields.
- **Time** — timestamps, durations, ordering, or illustrative timing.
- **Constraints and exceptions** — approvals, authorization, failure paths, limits, or rules.

For a long document, read it in chunks and keep a compact outline. Do not paste the entire
document into the candidate; use the diagram for structure and Archify cards for supporting
detail.

Ignore frontmatter, badges, navigation, license blocks, and boilerplate unless they carry
meaning for the requested diagram. Preserve exact product, protocol, API, command, and
environment names.

If the content has no discernible structure or relationships, ask one focused question before
proceeding. Do not invent missing relationships to make a diagram look complete.

## §2 Always ask the diagram type

Use the `question` tool when available; otherwise ask in plain text. Offer the ten Archify
types, with the best fit first and labeled as recommended. Keep the options short and let the
user add a custom answer.

| Content signal | Type | What it shows |
|---|---|---|
| Components, services, storage, deployment, trust boundaries | `architecture` | What a system is made of and how parts relate |
| Steps, approvals, CI/CD, runbooks, tool calls | `workflow` | A process across lanes and gates |
| Call chains, request lifecycles, async traces, returns | `sequence` | Ordered interactions between participants |
| Pipelines, ETL/ELT, lineage, data movement, consumers | `dataflow` | Where data comes from and goes |
| States, retries, waits, terminal outcomes | `lifecycle` | How something moves between states |
| Tables, columns, keys, cardinality | `erd` | A database schema |
| Classes, interfaces, members, inheritance, composition | `class` | Type relationships |
| Single-parent containment, module or capability breakdowns | `tree` | A hierarchy |
| Timestamped events, incident reviews, release histories | `timeline` | Events on a shared clock |
| Span durations, overlap, nesting, one request or run | `waterfall` | Where the time went |

Examples:

- A README describing a web app, API, cache, and database → recommend `architecture`.
- A deployment runbook with approvals and rollback → recommend `workflow`.
- A login request with browser, API, identity provider, and token return → recommend
  `sequence`.
- An article about order statuses and retries → recommend `lifecycle`.

The table is a recommendation aid, not an automatic decision. Always wait for the user's
answer. If the user says "you choose", pick the best fit and state it in the final reply.

## §3 Resolve the CLI and authoring root

The home-manager package installs `archify` on `PATH` and sets `ARCHIFY_ROOT` to the bundled
Archify package directory.

1. Check the CLI:

   ```bash
   command -v archify
   ```

2. Check the authoring root:

   ```bash
   test -f "${ARCHIFY_ROOT:-}/SKILL.md" && printf '%s\n' "$ARCHIFY_ROOT"
   ```

3. If `ARCHIFY_ROOT` is unset but `archify` is installed by this package, derive it:

   ```bash
   ARCHIFY_ROOT="${ARCHIFY_ROOT:-$(dirname "$(dirname "$(command -v archify)")")/share/archify}"
   ```

4. If the CLI or root is still missing, stop and tell the user:

   - run `home-manager switch --impure --flake ~/dotfiles#$(whoami)`, or
   - provide the path to an Archify package directory containing `SKILL.md`.

Never install Archify, run `npx`, or update the package on your own initiative. The Nix
package disables Archify's network update check because versions are managed by Nix.

## §4 Output path and the disposable workspace

### Final output path

- Default: `<slug>.html` in the directory where the skill was invoked.
- Derive `<slug>` from the document title or main subject: lowercase, kebab-case, ASCII, and
  short enough to be practical (for example `cache-miss-request.html`).
- If the user gives a directory, write `<slug>.html` inside it.
- If the user gives a filename, use it, adding `.html` if needed.
- Create missing parent directories before the final move.
- If the target file already exists, ask before replacing it.
- If the output directory is not writable, ask for another location.

### Disposable workspace

Create one timestamped workspace outside the output directory and reuse it for the whole
request:

```bash
WORK="${TMPDIR:-/tmp}/content-to-diagram-<slug>-<YYYYMMDD-HHMMSS>"
mkdir -p "$WORK"
```

The workspace holds only intermediates:

```text
$WORK/candidate.json
$WORK/diagram.html
```

Never create these beside the final HTML. In particular, do not create `.archify/`,
`candidate.json`, `*.delivery.json`, `*.finalize.json`, `*.finalize-summary.json`, or
`*.browser-check.json` in the output directory.

### `meta.output`

Archify requires `meta.output` to be a portable POSIX-relative `.html` path that resolves
inside the CLI working directory. Because the CLI runs in `$WORK`, set:

```json
"output": "diagram.html"
```

The final filename can differ from `diagram.html`; only the checked render is moved to the
requested path. Never put an absolute path, drive prefix, URI, backslash, or `..` segment in
`meta.output`.

## §5 Authoring through Archify

Before writing the candidate, read the authoritative files for the chosen type:

1. `$ARCHIFY_ROOT/SKILL.md` — especially "Native diagram authoring" and the Type router.
2. `$ARCHIFY_ROOT/references/authoring-defaults.md` — composition, layout, presentation, and
   mode defaults.
3. The selected type's schema: `$ARCHIFY_ROOT/schemas/<type>.schema.json`.
4. The selected type's example: the exact path listed in Archify's Type router (for example
   `$ARCHIFY_ROOT/examples/web-app.architecture.json`).

Use `archify guide "<scenario>" --json` only when the type choice or scenario is genuinely
ambiguous. Read examples for shape, not facts; use fresh IDs, wording, and placement.

Set at least:

```json
{
  "meta": {
    "title": "<reader-facing title>",
    "locale": "<content language>",
    "output": "diagram.html",
    "quality_profile": "showcase"
  }
}
```

Use `showcase` unless the user explicitly asks for a dense/standard diagram; then set
`meta.quality_profile` to `standard` and pass `--quality standard` to every CLI command.

Add the mode-specific fields the schema requires. Keep the source's meaning:

- Show the main path and the branches that change behavior.
- Keep relationship labels and direction; omit a label only when both endpoints fully imply
  it.
- Put supporting explanation in cards instead of adding unrelated edges.
- Use boundaries only for real isolation or ownership, never as decoration.
- Do not copy illustrative timings or amounts from an example into a document that does not
  provide them.

For a repository or codebase rather than a single document, Archify's
`$ARCHIFY_ROOT/references/repository-authoring.md` and its `--repo-root` workflow apply. State
the scope and evidence level in the reply.

## §6 Clean delivery and repair

### Validate, render, check

Run every command from `$WORK`:

```bash
cd "$WORK"

archify validate <type> candidate.json --quality showcase --json
archify render   <type> candidate.json diagram.html --quality showcase
archify check    diagram.html --json
```

- All three commands must exit zero.
- `archify check` runs without `--require-provenance`, because this pipeline creates no
  delivery sidecar. A passing receipt reports `provenance: "unknown"`; that is expected.
- `archify render` writes only `$WORK/diagram.html`.
- `archify validate` and `archify check` write no files in the output directory.

### Move only the HTML

After all checks pass:

```bash
OUT="<absolute-output-path>"
if [ -e "$OUT" ]; then
  # Ask the user before replacing an existing target.
  :
fi
mv "$WORK/diagram.html" "$OUT"
rm -rf "$WORK"
```

The output directory receives exactly one new file: `$OUT`. Do not copy receipts, candidate
JSON, or temp renders alongside it.

### Failures and repair

1. A non-zero exit is failure. Read the JSON printed by the failing command.
2. Consult `$ARCHIFY_ROOT/references/authoring-contract.md` for schema, geometry, label, or
   viewport diagnostics.
3. Repair `candidate.json` in `$WORK`, preserving the requested meaning and source content.
4. Rerun `validate`, `render`, and `check` from `$WORK`. Limit focused repairs to two rounds per
   persistent issue; if it still fails, report the concrete diagnostic.
5. Remove any previous `$WORK/diagram.html` before rerendering if the renderer refuses to
   replace it.

Do not change unrelated nodes, labels, or relationships to make a diagnostic disappear. Do not
create evidence sidecars in the output directory to diagnose a failure; the JSON on stdout is
the evidence.

### Cleanup

Always delete the workspace before replying, on success and on failure:

```bash
rm -rf "$WORK"
```

If the user explicitly asks to keep the candidate for continued iteration, explain that this
adds a file outside the requested output directory and obtain consent before keeping it.

### If the user explicitly requests delivery receipts

`archify deliver` and `archify finalize` create `.delivery.json` and (for `finalize`)
`.finalize*.json` and `.browser-check.json`. This skill does not use them by default because
the user wants a single HTML file. If audit receipts are explicitly requested, run those
commands in a separate evidence directory outside the output directory, and move only the HTML
to the requested path. Disclose where the receipts are stored.

## §7 Reply

Lead with a clickable Markdown link using the absolute output path, for example:

```markdown
Created [Checkout request flow](/absolute/path/checkout-request.html).
```

Then, when useful, add one or two sentences:

- the diagram's key takeaway, or
- the abstraction level and deliberate omissions,
- whether timings, amounts, or other values are illustrative,
- that automated schema and artifact checks passed and the diagram was not visually reviewed,
- any requested content that was merged or dropped during repair.

Do not recap commands, repair rounds, checks, or paths to deleted intermediates. The output
directory contains only the HTML.

## §8 Environment and deployment

- `archify` and `$ARCHIFY_ROOT` are provided by `~/dotfiles/pkgs/archify.nix` through the
  home-manager overlay and `modules/common/packages.nix`.
- The package pins upstream Archify at `v3.2.0` (commit
  `208acba8d412335185b2056fedf54b3405df43fb`).
- New skill files must be Git-tracked before deployment because flakes only see tracked files:

  ```bash
  git add pkgs/archify.nix skills/content-to-diagram
  home-manager switch --impure --flake ~/dotfiles#$(whoami)
  ```

- After deployment, verify with:

  ```bash
  archify --help
  archify doctor
  test -f "$ARCHIFY_ROOT/SKILL.md"
  ```
