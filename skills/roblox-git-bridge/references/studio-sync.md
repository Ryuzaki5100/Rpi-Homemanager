---
name: roblox-git-bridge
description: Handshake, save_place vs syncback, and the three-way divergence rules for driving Roblox Studio from a repository.
---

# Studio sync: handshake, saving, and divergence

## The four surfaces

| Surface | Holds | Authority |
|---|---|---|
| `src/**` | scripts | source of truth for code |
| `place/*.rbxlx` | geometry, lighting, terrain | source of truth for the world |
| Studio session | live DataModel | disposable runtime |
| `origin/main` | history | source of truth for history |

## Handshake (run before any edit)

1. `list_roblox_studios`.
   - empty → Studio closed, no place loaded, or "Enable Studio as MCP server" off.
   - cloud entry → match `placeId` from `roblox.json`.
   - local entry → match the `file` field (local places have no placeId).
   - `mode: "Unavailable"` → stray window, ignore it.
2. `get_studio_state` → must be `Edit`. Stop play mode before editing scripts.
3. `search_game_tree` for the sentinel (`ServerScriptService.<Name>Boot`).
   Missing means Rojo is not connected: a file edit will not reach Studio, so say
   so instead of editing.
4. Optional: `start_stop_play` → `get_console_output` → stop. This proves the
   runtime, not just the tree.

## Two directions, two mechanisms

**files → Studio** (scripts): Rojo live sync on port 34872. Automatic while the
plugin is connected. Studio-side edits to the same script are lost — there is no
conflict detection in Rojo.

**Studio → files** (geometry): MCP `save_place`. For a **local** place it writes
the tracked `.rbxlx` on disk, and `git diff` then shows the change. For a cloud
place it only creates a cloud version; nothing reaches disk.

**Studio → files** (scripts, rare): `rojo syncback --input <saved place>` writes
mapped instances back out as files. Cautious mode: show the diff, get approval,
then apply. Never part of the automatic loop.

## Divergence rules (baseline = `git HEAD`)

| files vs HEAD | Studio vs HEAD | Action |
|---|---|---|
| same | same | nothing to do |
| changed | same | Rojo already pushed; commit and push |
| same | changed | show the diff, ask, then write the file |
| changed | changed, identical | no action |
| changed | changed, different | **halt**, show both diffs |

Autosync (only when the user explicitly asks) applies the first four rows; the
last row always halts. Announce which row applied so the user can see the
reasoning.

## Command shape

```
sync:
  1. git fetch; halt if diverged (ahead > 0 and behind > 0)
  2. git pull --ff-only
  3. compare each mapped script (script_read vs disk)
  4. save_place only when scripts are settled
  5. commit + push approved changes
```

`scripts/status.sh` covers step 1; the comparison in step 3 requires MCP and is the
agent's job.
