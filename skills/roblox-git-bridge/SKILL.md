---
name: roblox-git-bridge
description: Attaches a Roblox Studio game project to a GitHub repository the user supplies as a URL or path, then keeps files, Studio and the remote in sync. Sets up Rojo filesystem-to-DataModel mapping, a pinned devenv toolchain, Project-level MCP config, .gitignore/tooling configs, GitHub Actions lint+build CI, the commit/push loop, cautious syncback for Studio-side edits, and Open Cloud publish on request. Use when the user pastes a GitHub repo link for a Roblox game, asks to put a Roblox/Studio project under version control or on GitHub, mentions Rojo, says "bridge" or "sync my Roblox game", asks which side is ahead, or wants Studio changes pushed to a remote.
---

# roblox-git-bridge

Connect a Roblox Studio game to a git repository, then keep four surfaces honest:
`src/` (scripts), the tracked `.rbxlx` (geometry), the live Studio session
(runtime), and `origin/main` (history).

## Step 0 — Read the guide first (mandatory)

`read GUIDE.md` before acting. It holds the ordered playbook; this file is only
the router.

## Core rules (always apply)

1. Files are the source of truth for **scripts**; the tracked `.rbxlx` is the
   source of truth for **geometry**; the Studio session is disposable runtime.
2. The repo location comes from the user. Verify it (`git ls-remote`, or `git -C
   <path> remote -v`) before writing; never invent an owner or name. The repo name
   and the game name are different things — never derive one from the other.
3. Prefer the **local place** as canonical: MCP `save_place` writes to disk only
   for local `.rbxl`/`.rbxlx` places. A cloud place saves a cloud version that git
   never sees.
4. Cautious by default. Autosync only when the user explicitly asks ("sync",
   "autosync", "I don't know which is ahead"). Two-sided divergence always halts
   with both diffs shown; never guess.
5. Idempotent writes only: every file creation is guarded, and the scaffold runs
   `scripts/bootstrap.sh --dry-run` first and waits for approval.
6. Never `git push --force`, never `reset --hard`, never delete files you did not
   create in this session.
7. Verify the Studio session before editing: cloud sessions by `placeId`, local
   sessions by the `file` field, then the sentinel script in the tree.
8. One Rojo server only. `rojo serve` and `devenv up` cannot both hold port 34872.
9. Scripts are edited in files, never in Studio: Rojo overwrites Studio-side
   script edits silently, with no conflict detection.
10. Report per surface (files, Studio, GitHub) at the end of any sync.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Run the end-to-end setup | `GUIDE.md` | Ordered playbook: preflight → attach → map → devenv → build → CI |
| Wire the git remote, handle empty/diverged repos | `references/repo-attach.md` | `git`/`gh` semantics, LFS vs plain commits, `.gitattributes` |
| Place scripts correctly / retrofit an existing game | `references/rojo-mapping.md` | Service mapping, file suffixes, sourcemap, package layout |
| Drive Studio safely, sync both directions | `references/studio-sync.md` | MCP handshake, `save_place`, `syncback`, divergence table |
| Set up Actions or publish the place | `references/ci-and-publish.md` | Workflow, pinned tools, Open Cloud secrets, tag gating |
| Avoid repeating known failures | `references/gotchas.md` | Nine failures that cost real debugging time, with evidence |
| Start a new project's identity file | `templates/roblox.json` | `repo`, `placeFile`, `game`, `sentinel` |
| Start a new Rojo mapping | `templates/default.project.json` | Four-service tree with baseplate and spawn |
| Pin the toolchain per repository | `templates/devenv.nix` | rojo/selene/stylua/luau-lsp/lune + scripts + tasks |
| Add CI | `templates/ci.yml` | lint, format check, build, artifact |
| Give future agents the contract | `templates/AGENTS.md` | Repo-local operating rules |
| Scaffold or repair a repository | `scripts/bootstrap.sh` | `--dry-run` plan, then idempotent apply |
| Copy the working helper scripts into a new repo | `scripts/repo/` | `status`, `sync`, `preflight`, `studio-open`, `studio-mcp`, `publish` |

## Workflow

1. Collect the repo location and the game name; run `scripts/bootstrap.sh --dry-run`
   and show the plan (`GUIDE.md` §2).
2. Attach the remote and reconcile history (`references/repo-attach.md`).
3. Write `roblox.json`, then `default.project.json` and `src/` layout
   (`templates/roblox.json`, `templates/default.project.json`, `references/rojo-mapping.md`).
4. Add `devenv.nix`/`devenv.yaml`, project `.opencode/opencode.json` and `.mcp.json`
   so any MCP client finds the Studio server by name (`templates/devenv.nix`).
5. Build and open the local place; prove the sentinel reaches Studio
   (`references/studio-sync.md`).
6. Add CI and `AGENTS.md` (`templates/ci.yml`, `templates/AGENTS.md`,
   `references/ci-and-publish.md`).
7. State the daily loop back to the user, and stop before anything that rewrites
   history or publishes.

## Output location / deployment

Write into the user's game repository (default `~/roblox/<repo>`). The skill lives
in `~/dotfiles/skills/roblox-git-bridge/` and is deployed by `home-manager switch`
to `~/.config/opencode/skills/roblox-git-bridge/`.

## Tools

`read`, `write`, `edit`, `bash`, `glob`, `grep`, `question`, plus the Roblox MCP
tools when a Studio session is connected (`list_roblox_studios`,
`get_studio_state`, `search_game_tree`, `script_read`, `execute_luau`,
`start_stop_play`, `get_console_output`, `screen_capture`, `save_place`).
