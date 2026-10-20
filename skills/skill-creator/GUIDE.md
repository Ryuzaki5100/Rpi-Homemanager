---
name: skill-creator
description: Deep authoring guide for skill-creator — the full router pattern, topology matrix, SKILL.md and routing templates, context-budget rules, non-Markdown asset conventions, validation checklist, and a worked example. Loaded on demand by the skill-creator SKILL.md router.
---

# Skill Authoring Guide (router pattern)

Reference for the `skill-creator` skill. The always-on rules are in `SKILL.md`; this guide holds
the detail. Read a section only when the corresponding step in the workflow needs it.

- §1 Gathering requirements
- §2 Topology decision matrix
- §3 Frontmatter rules and the `SKILL.md` template
- §4 Context-budget rules
- §5 Routing tables and reference conventions
- §6 Non-Markdown assets
- §7 Validation checklist
- §8 Worked example

---

## §1 Gathering requirements

Collect the minimum needed to author a routable skill. Ask interactively with the `question`
tool; if the user is non-interactive, infer from context and state your proposed defaults.

| Field | Rule / question |
|---|---|
| **Name** | `^[a-z0-9]+(-[a-z0-9]+)*$`, 1–64 chars, no leading/trailing/consecutive hyphens. Must equal the directory name. |
| **Description** | 1–1024 chars. Must name the concrete triggers (verbs + keywords + synonyms) *and* the behavior. This is the only text the agent sees before loading the skill, so it must be self-sufficient for selection. |
| **Purpose** | One or two sentences: what the skill accomplishes. |
| **Triggers** | Phrases/situations that should cause the agent to load it. |
| **Inputs** | What the user provides (a path, pasted text, a repo, nothing). |
| **Outputs** | Files/artifacts/actions produced, and where they go. |
| **Mode** | Plan-first (asks clarifying questions) or autonomous. |
| **Tools** | Which tools the skill uses (`read`, `write`, `edit`, `bash`, `glob`, `grep`, `websearch`, `question`). |

If the request is vague, ask 2–3 clarifying questions such as:
- "What specific task should the agent perform when this skill is loaded?"
- "Should it ask questions first or execute autonomously?"
- "What tools should it use, and what does it produce?"

## §2 Topology decision matrix

Pick the **smallest** topology that fits. Growing a skill later is fine; bloating it early is not.

| Topology | Files | Use when | Example |
|---|---|---|---|
| **single** | `SKILL.md` | The task is short and self-contained; nothing is worth loading on demand. | `git-release`-style one-flow skills. |
| **router+guide** | `SKILL.md`, `GUIDE.md` | One deep body of reference/rules is needed, but only after triggering. | This skill; `tui-bubble-tea-creator`. |
| **router+references** | `SKILL.md`, `GUIDE.md`, `references/<topic>.md`, plus `scripts/`/`templates/`/`assets/` as needed | Multiple independent domains of detail; each is read only for a specific subtask. | A skill covering several formats or workflows. |

Rules of thumb:
- If `SKILL.md` would exceed ~200 lines to hold everything, split.
- If a section is needed for *only some* tasks, it belongs in a reference, not `SKILL.md`.
- Prefer more, smaller references over one giant `GUIDE.md` once `GUIDE.md` passes ~500 lines.

## §3 Frontmatter rules and the `SKILL.md` template

### Frontmatter

```yaml
---
name: <skill-name>
description: <triggers + behavior, 1–1024 chars>
---
```

- `name` must match the containing directory exactly.
- `description` is the selection signal — include synonyms and the concrete nouns a user/agent
  would say ("TUI", "terminal app", "bubbletea") plus what the skill does.
- Optional OpenCode keys belong under `metadata` (e.g. `opencode/slash: "true"`,
  `opencode/autoinvoke: "false"`), not as custom top-level fields.

### `SKILL.md` body template (router)

```markdown
# <skill-name>

<One sentence: what this skill does and the core mental model.>

## Step 0 — Read the reference first (mandatory)   <- only if §refs exist
Read `<base-dir>/GUIDE.md` (and any reference the routing table calls for) before acting:
`read <base-dir>/GUIDE.md`.

## Core rules (always apply)
<5–10 non-negotiable rules, numbered. These must be enough to be correct on their own.>

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| <condition> | `GUIDE.md` §N | <what it gives> |
| <condition> | `references/<topic>.md` | <what it gives> |

## Workflow
1. <step>  → <which file/rule applies>
2. <step>
...

## Output location / deployment
<Where files are written; how the skill is deployed.>

## Tools
<Which tools, and for what.>
```

For a **single**-topology skill, drop the `Step 0` block and the `Files & routing` table, and
inline the full instructions in the workflow.

## §4 Context-budget rules

The goal: `SKILL.md` is loaded on **every** invocation and must stay small; references are loaded
**on demand** and can be large.

- **Always-loaded (`SKILL.md`):** frontmatter, when-to-use, core non-negotiable rules, the routing
  table, the ordered workflow, output/deploy notes, tool list. Target ≤ ~150–200 lines.
- **On-demand (`GUIDE.md`, `references/*`):** deep rules, templates, long examples, tables,
  edge-case catalogues, platform-specific detail, large code blocks.
- **Never duplicate.** If content is in a reference, `SKILL.md` points to it; it does not restate
  it. If a rule must hold unconditionally, it is inlined in `SKILL.md` and *not* repeated (or
  expanded) verbatim in a reference.
- **Graceful degradation.** A run that (wrongly) skips the reference must still be *correct*, just
  less detailed. This is what the inline "Core rules" block guarantees.
- **One concern per reference.** Name references after the concern (`references/auth.md`), not
  after the skill.

## §5 Routing tables and reference conventions

### Routing table

Every supporting file must appear exactly once in the `SKILL.md` routing table, paired with the
condition that triggers reading it:

```markdown
| When you need to… | Read | Purpose |
|---|---|---|
| Parse the job description | `references/parsing.md` | Extraction schema + examples |
| Render the final document | `templates/document.latex` | Boilerplate to fill |
```

An agent reads a supporting file **only** when `SKILL.md` directs it to. Therefore:
- Always add the mandatory `Step 0` line for the primary reference.
- Make each row's "When you need to…" a concrete, recognizable condition.
- Order rows to match the workflow.

### Reference conventions

- Filenames: lowercase kebab-case (`references/api-schema.md`).
- Reference files may have their own frontmatter `name` (matching the skill) and a short
  `description`, but it is the `SKILL.md` table that governs routing.
- Start each reference with one sentence stating its scope.
- Cross-link sparingly with relative paths (`see references/errors.md`).
- Do **not** put a full copy of `SKILL.md`'s core rules in a reference.

## §6 Non-Markdown assets

| Directory | Contents | Notes |
|---|---|---|
| `scripts/` | Executable helpers the agent runs | Invoke via an interpreter (`bash script.sh`, `python x.py`) so it works even if the exec bit is lost. |
| `templates/` | Boilerplate to fill (`.latex`, `.json`, `.md`) | Reference by relative path from `SKILL.md`. |
| `assets/` | Static data/images/styles | Reference by relative path. |

Reference every asset from the routing table or workflow; an unreferenced asset will never be used.

## §7 Validation checklist

Run this before declaring the skill done:

- [ ] Directory name equals frontmatter `name`; both match `^[a-z0-9]+(-[a-z0-9]+)*$`.
- [ ] `SKILL.md` is spelled in all caps and lives at the skill root.
- [ ] Frontmatter parses; `description` is 1–1024 chars and names concrete triggers.
- [ ] `SKILL.md` contains a **Files & routing** table (unless topology is `single`).
- [ ] Every supporting file is listed in the routing table exactly once.
- [ ] A mandatory `Step 0: read <primary reference>` exists if any reference is present.
- [ ] No orphan files (present but unreferenced) and no duplicated content across files.
- [ ] All paths are relative to the skill directory; no absolute paths.
- [ ] `SKILL.md` is within its line budget; overflow was moved to a reference.
- [ ] Core non-negotiable rules are inlined so the skill is correct even if a reference is skipped.
- [ ] Non-Markdown assets live under `scripts/`/`templates/`/`assets/` and are referenced.

## §8 Worked example

A skill that tailors resumes to job postings, with parsing detail and a template:

```
skills/resume-tailor/
  SKILL.md
  GUIDE.md
  references/parsing.md
  references/keywords.md
  templates/resume.latex
```

`SKILL.md` (router, abbreviated):

```markdown
---
name: resume-tailor
description: Tailors a one-page LaTeX resume to a job description (given as a URL, file path, or
  pasted text). Use when the user mentions tailoring a resume for a specific company, role, or job
  posting.
---

# resume-tailor

Produce an ATS-friendly, one-page LaTeX resume matched to a job description.

## Step 0 — Read the guide first (mandatory)
`read <base-dir>/GUIDE.md` before doing anything else.

## Core rules (always apply)
1. Exactly one page — trim, never shrink margins below the template's.
2. Keywords must be drawn verbatim from the job description.
3. Never invent experience; only rephrase what the knowledge base supports.
4. Every action verb used in the document must be unique.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Understand the overall method | `GUIDE.md` | Full workflow and rules |
| Parse the job description | `references/parsing.md` | Extraction schema + examples |
| Choose keywords | `references/keywords.md` | Ranking and de-duplication |
| Render the document | `templates/resume.latex` | Boilerplate to fill |

## Workflow
1. Read `GUIDE.md`. 2. Parse the JD (§parsing). 3. Rank keywords (§keywords). 4. Fill the template.
5. Validate one page and unique verbs.

## Output location / deployment
Write to `~/my_resumes/<company>/<role>.tex`. Deploy the skill with `home-manager switch`.

## Tools
`read`, `write`, `edit`, `bash` (compile with `pdflatex`), `question`.
```

Note how the router never restates the parsing schema or the keyword algorithm — it only tells the
agent *when* to read each file. That is the pattern: **small always-loaded router, precise routing,
deep files on demand.**
