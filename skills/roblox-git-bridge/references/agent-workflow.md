# Multi-agent topology for a Roblox project

How to run several agent roles over one game repository without a paid
orchestrator, a shared chat window, or a server. The vault is the memory, `noclip`
is the scheduler, Studio is the one resource that must be serialized.

## 1. Why this shape

Three constraints decide everything:

1. **Studio is a single mutable process.** `execute_luau` runs on its main thread
   and freezes it until it yields; Rojo is bound to one checkout. Parallel Studio
   writes do not "go faster", they drop the MCP connection and half-apply edits.
2. **Agents do not share context.** There is no shared session between
   processes. Whatever is not written down does not exist for the next role.
3. **Two agents editing the same checkout produce garbage.** Not conflicts —
   garbage, because neither knows the other's intent.

Therefore: a file-based queue (durable, greppable, no server), one worktree per
task (isolation), and one lane that is strictly serialized (Studio).

## 2. Roles

Seven roles, each with a surface it owns and a surface it is forbidden to touch.
The point is not specialisation for its own sake — it is that permission denial
is the only reliable way to stop an agent from "helpfully" editing the wrong file.

| Role | Owns | Writes | Forbidden | Lane | Model posture |
|---|---|---|---|---|---|
| `noclip` | deciding, delegating | `40-tasks/` | every other write | files | strongest (`v4-pro#high`) |
| `librarian` | the queue and the record | task notes, ADRs | any repo file | files | cheapest |
| `designer` | game design | `10-design/`, `00-brief/` | Luau, Studio | files | strongest (taste) |
| `scripter` | Luau | `src/`, Rojo mapping | `place/`, `save_place` | files | code-specialist |
| `asset-smith` | world + assets | Studio instances, `20-assets/` | scripts | studio | mid |
| `audio` | sound | cue sheets, `Sound` instances | inventing asset IDs | files→studio | cheap |
| `qa` | verification | `50-log/` reports | every edit | studio | cheapest |
| `builder` | integration, release | merges, place file | design decisions | files | cheap + cautious |
| `lore-keeper` | wiki corpus | `60-lore/` | code, design, `game_hooks` | files | cheapest |

Definition files are **project-scoped**: `noclip agents install` writes them to
`<repo>/.opencode/agents/`, so they load only while working in that project (or a
worktree of it) and the picker stays Build/Plan everywhere else. This is not just
tidiness — permission rules bind to an absolute vault path, so a globally
installed role set is only correct for one project. `noclip agents check` reports
drift and `noclip doctor` fails on it.

`noclip` itself is a primary agent: classify, queue or delegate, never implement.

### Division of labour, concretely

- A player-facing idea goes to `designer`, which must produce numbers and open
  questions. If it needs code, the design note is the input to `scripter`.
- `librarian` turns that note into 1–3 task notes. It never decides design.
- `scripter` implements in `src/` and proves it with `selene`, `stylua` and
  `rojo build`. It never opens Studio, so its work is verifiable in CI terms.
- `asset-smith` builds the world in Studio and records every asset in the
  manifest. It never writes a script, because Rojo would overwrite it.
- `audio` sources and normalises sound, writes the cue sheet, and leaves Studio
  insertion as a separate studio-lane hand-off.
- `qa` runs the game, drives input, reads console output, captures screenshots.
  It reports; it never patches.
- `builder` merges branches, builds the place, and is the only role that may
  publish — and only on explicit request.

If a single task seems to need two roles, it is two tasks. That rule is what keeps
the queue honest.

## 3. Lanes

| Lane | Concurrency | Working directory | Serialized by |
|---|---|---|---|
| `files` | `jobs` (default 2) | `.noclip-worktrees/wt-<id>` on branch `noclip/<id>` | git, per branch |
| `studio` | exactly 1 | the main checkout | `.locks/studio` in the vault |

The studio lock is a directory created with `mkdir`, which is atomic on POSIX
filesystems. The pid is written inside so `noclip doctor` can distinguish a live
holder from a stale lock.

Consequence worth stating to the user: six agents can be busy while only one is
in Studio. That is the design, not a bottleneck to optimise away.

## 4. Vault layout

Outside the repository, its own git repo:

```
00-brief/      pillars, audience, scope            (human + designer)
10-design/     systems, loops, economy             (designer)
20-assets/     manifests, style anchors, prompts   (asset-smith)
30-audio/      cue sheets, loudness, licences      (audio)
40-tasks/      backlog/ active/ done/              (librarian + noclip)
50-log/        one append-only log per run         (noclip)
90-decisions/  ADRs                                (anyone)
templates/     task.md, decision.md                (librarian)
```

`noclip init` creates this idempotently and writes `.noclip` in the repo.

## 5. Task note

```markdown
---
id: 0007-inventory-ui
title: Inventory HUD panel
agent: asset-smith
lane: studio
status: backlog
priority: 3
depends:
acceptance: panel opens on Tab, 3 slots, no console errors
---
## Intent
## Log
```

- `id` is the filename stem.
- `acceptance` must be one line that a `qa` run can fail unambiguously. This is
  the single highest-leverage field: vague acceptance is why agents "finish"
  without delivering.
- `depends` lists IDs that must land first.
- State is the directory (`backlog` → `active` → `done`); `status` mirrors it for
  humans.

Claiming is `mv` into `active/` — atomic, so every racing worker but one fails
and treats the failure as "someone else has it".

## 6. Canary task

Before dispatching anything real, queue one studio-lane `qa` task:

```markdown
---
id: 0001-verify-the-studio-bridge-end-to-end
agent: qa
lane: studio
acceptance: The sentinel exists, play mode runs and stops cleanly, and a screenshot plus a console excerpt are attached
---
```

Steps: `list_roblox_studios` (match by `placeId` or local `file`) →
`get_studio_state` (must be `Edit`) → `search_game_tree` for the sentinel →
`get_console_output` baseline → `start_stop_play` true → screenshot + console →
`start_stop_play` false.

If that task fails, every other agent's failures are noise. Fix the bridge first.

## 7. Dispatcher

```
noclip init [--vault DIR] [--repo DIR]   scaffold vault + .noclip (idempotent)
noclip new "Title" [--agent R] [--lane files|studio]
noclip status                            queue board + studio lock
noclip run [--once] [--jobs N] [--agent R] [--dry-run]
noclip merge TASK_ID                     merge noclip/TASK_ID, drop the worktree
noclip doctor                            toolchain, agents, vault, stale lock
```

`.noclip` keys: `vault`, `jobs`, `worktrees`, `opencode`, `format`, `lock_wait`.
Precedence: project config > environment > default.

Each dispatch is exactly one process:

```sh
opencode run --agent <role> --auto --format <fmt> --title <id> "<task note path>"
```

Exit 0 → the note moves to `done/` with a `## Result`. Non-zero → back to
`backlog/` with `status: blocked` and a `## Blocked` section quoting the log. A
worker killed mid-run is requeued by an exit trap, so a note is never stranded in
`active/`.

## 8. Cost posture

Split the work by what it costs:

- **Deterministic ops** — import, insert, build, publish, git. Tool calls, not
  inference. Zero model cost.
- **Reasoning** — design, Luau, review. Model cost only; runs on whatever the
  user's OpenCode plan already covers.
- **Generative media** — meshes, textures, scenes, images, sound. The only part
  that is genuinely metered, and mostly free: Studio's own `generate_mesh`,
  `generate_scene`, `generate_texture`, `generate_material`,
  `generate_procedural_model` need no credits, `search_asset` finds existing art,
  and CC0 libraries cover sound.

Two rules keep this bounded: manifest-before-generate, and `search_asset` before
`generate_mesh`. Regeneration is the main way a pipeline like this wastes money.

## 9. Failure modes and what they mean

| Symptom | Real cause |
|---|---|
| Two agents fight over Studio | `asset-smith` and `qa` both dispatched as `files`; the lane field is wrong |
| Note stuck in `active/` | worker was killed; the exit trap did not run (SIGKILL) — move it back |
| Branch conflicts on merge | two tasks edited the same lines; that is a design conflict, not a git problem |
| Agent exits 0 with nothing done | acceptance was not falsifiable |
| Place file churn in every diff | an agent called `save_place`; only `builder` may |
| Vault "disappears" in a worktree | vault was put inside the repo — move it out |

## 10. Scaling

- Add a role only when a surface is genuinely unowned. New role = new agent file
  + row in the vault `AGENTS.md` + a permission boundary that means something.
- Raise `jobs` when the bottleneck is authoring, never when it is Studio.
- Multiple Studio instances (several places open) can each take a lock, keyed by
  place id, if the project ever needs it. One place, one lock, is the default.

## 11. Lore corpus

A Roblox game in an established fiction needs reference material an agent can
read one note at a time, not a summary. Keep it in `60-lore/`, one note per
source article, generated rather than written:

- **Provenance is mandatory.** `source`, `revid`, `retrieved`, `license` in every
  note. A corpus without revision ids cannot be re-verified or diffed.
- **Bulk path is the wiki's own API**, not page scraping: 50 titles per request
  with wikitext included, which keeps cost near zero and output free of site
  chrome.
- **`game_hooks` is the bridge.** Generated notes are inert; a designer-owned
  `game_hooks:` list turns a description into "non-euclidean loop → no reliable
  minimap". Re-renders must preserve it.
- **Redirects become `aliases:`**, so common names still resolve.
- **Canon conflicts are data, not bugs.** Label them; never pick silently.

Rendered text is CC-BY-SA. Attribute per note and in `_attribution.md`, and quote
rather than republish when moving text out of the vault.
