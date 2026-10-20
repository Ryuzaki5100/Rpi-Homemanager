---
name: skill-creator
description: Interactive wizard that creates new opencode skills. Gathers the skill name, description, and behavior, chooses a file topology (single-file, router+guide, or router+references), then generates a context-efficient SKILL.md router with on-demand supporting Markdown files and validates the result. Use when the user asks to create, scaffold, or design a new opencode skill, or to convert an existing prompt/checklist into a skill.
---

# skill-creator

Create opencode skills that are **lean at load time and deep on demand**. Every skill you
generate is a *router*: a short `SKILL.md` that is always loaded, plus supporting Markdown and
assets that the agent reads only when the task needs them. This keeps context small while
keeping the agent's understanding of *what to read, and when* high.

## Step 0 — Read the authoring guide first (mandatory)

Before generating anything, read `GUIDE.md` from this skill's base directory:

```
read <skill-base-dir>/GUIDE.md
```

It contains the full router-pattern spec, the topology decision matrix, the exact templates, the
context-budget rules, worked examples, and the validation checklist. The rules below are inlined
so a skipped reference degrades gracefully — but the templates and examples are only in `GUIDE.md`.

## Core rules (always apply)

1. **Frontmatter is required.** Every `SKILL.md` starts with YAML frontmatter containing `name`
   and `description`. `name` must match its directory: `^[a-z0-9]+(-[a-z0-9]+)*$`, 1–64 chars,
   no leading/trailing or consecutive hyphens. `description` is 1–1024 chars and must be specific
   enough that the agent knows exactly when to load the skill (name the triggers, not just the topic).
2. **`SKILL.md` is a router, not a knowledge dump.** It contains only what is needed on *every*
   invocation: frontmatter, when-to-use, the non-negotiable core rules, a **Files & routing**
   table, the ordered workflow, and the tool list. Target ≤ ~150–200 lines. Push depth into
   supporting files.
3. **Route explicitly.** If any supporting file exists, `SKILL.md` must contain a mandatory
   `Step 0: read <file>` instruction and a **Files & routing** table mapping
   `| When you need to… | Read | Purpose |`. The agent only reads supporting files when directed,
   so an unlisted file is an unread file.
4. **One concern per file.** `GUIDE.md` = the primary playbook/reference. `references/<topic>.md`
   = one focused deep-dive each. Never duplicate content between `SKILL.md` and a supporting file,
   or between two supporting files — duplication bloats context and drifts out of sync.
5. **Graceful degradation.** Inline the 5–10 rules that must hold on *every* run (so skipping a
   reference never produces a wrong result). Anything that is merely "better with detail" goes to
   a supporting file.
6. **Paths are relative to the skill directory** (e.g. `GUIDE.md`, `references/api.md`,
   `scripts/run.sh`). Never hardcode absolute paths. Use lower-kebab filenames.
7. **Non-Markdown assets** go in named subdirectories: `scripts/`, `templates/`, `assets/`.
8. **`SKILL.md` must be spelled in all caps** and live at `<skill-dir>/SKILL.md`.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Gather requirements and pick a file topology | `GUIDE.md` §1–2 | Intake questions, topology matrix |
| Write the frontmatter and the router body | `GUIDE.md` §3 | Frontmatter rules + `SKILL.md` template |
| Decide what stays inline vs. what moves out | `GUIDE.md` §4 | Context-budget rules |
| Write a routing table / on-demand references | `GUIDE.md` §5 | Routing-table template + reference conventions |
| Package scripts/templates/assets | `GUIDE.md` §6 | Non-Markdown assets |
| Validate the finished skill | `GUIDE.md` §7 | Validation checklist |
| See a full worked example | `GUIDE.md` §8 | Worked example (router + guide + reference) |

## Workflow

### 1. Gather requirements
Ask (using the `question` tool when interactive, otherwise infer and propose defaults):
- **Skill name** — lowercase kebab-case per rule 1.
- **Description** — triggers + behavior, ≤1024 chars.
- **What it accomplishes** — the core behavior, in one or two sentences.
- **Inputs and outputs** — what the user provides, what the skill produces.
- **Mode** — plan-first (ask questions) vs. autonomous execution.
- **Tools** — which of `read`/`write`/`edit`/`bash`/`glob`/`grep`/`websearch`/`question` it needs.

If the request is vague, ask 2–3 clarifying questions before proceeding.

### 2. Choose a topology
Pick the smallest topology that fits (details in `GUIDE.md` §2):
- **single** — one `SKILL.md` only. For short, self-contained tasks.
- **router+guide** — `SKILL.md` + `GUIDE.md`. For one deep playbook/reference.
- **router+references** — `SKILL.md` + `GUIDE.md` + `references/<topic>.md` (+ `scripts/`,
  `templates/`, `assets/` when needed). For multi-domain skills.

### 3. Build the routing map
Before writing files, list every file and, for each, the exact condition that makes the agent read
it. This becomes the **Files & routing** table in `SKILL.md` (§5).

### 4. Author the files
Write `SKILL.md` first using the §3 template, then each supporting file using the conventions in
§5–6. Keep every file within its budget; move overflow into a new focused reference rather than
growing `SKILL.md`.

### 5. Validate
Run the §7 checklist: name matches directory, frontmatter parses, description within range, a
routing table is present and lists **every** supporting file, no orphan or duplicated files,
relative paths only, and `SKILL.md` within its line budget.

## Output location and deployment

- Write the skill to `~/dotfiles/skills/<skill-name>/` (create the directory first).
- Create supporting files and subdirectories in the same folder.
- To deploy globally, run `home-manager switch` in `~/dotfiles/`. After that the skill is
  available at `~/.config/opencode/skills/<skill-name>/` — the whole directory is deployed, so
  `GUIDE.md`, `references/`, `scripts/`, and `templates/` ship alongside `SKILL.md`.
- Tell the user the created path and the deploy command when done.

## Tools

`question` (interactive intake), `read` (this `GUIDE.md` + existing skills for reference),
`write`/`edit` (author files), `bash` (create directories), `glob`/`grep` (inspect existing
skills to match conventions).
