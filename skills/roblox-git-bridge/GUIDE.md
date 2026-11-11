---
name: roblox-git-bridge
description: Deep playbook for attaching a Roblox Studio game to a GitHub repository and keeping files, Studio and the remote in sync. Loaded on demand by the roblox-git-bridge SKILL.md router.
---

# Roblox ↔ Git bridge — playbook

Ordered, idempotent, and safe to re-run. Each section names what to verify before
moving on.

## 1. Preflight

Check before promising anything:

```sh
command -v rojo selene stylua luau-lsp lune git jq
git -C <repo> remote -v && git -C <repo> status --short
ls /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP     # macOS
ls ~/Documents/Roblox/Plugins                                  # Rojo plugin
```

A project without `rojo` can still be wired up (devenv provides it), but nothing
can reach Studio without the StudioMCP binary and the plugin.

## 2. Establish or adopt the repository

1. Get the repo location from the user. It is either an existing directory or a
   URL to clone.
2. Verify reachability: `git ls-remote <url>` (SSH) or `git -C <dir> ls-remote
   origin`. Empty output is normal for a new repository and means "clean attach".
3. If the remote already has commits, read `references/repo-attach.md` before
   merging anything.
4. Record identity **once** in `roblox.json`: repo name, place file path, game
   name, optional `placeId`/`universeId`, and a sentinel script path. The repo
   name and the game name are independent; ask for the game name, never derive it.

## 3. Map the filesystem into the DataModel

Copy `templates/default.project.json` and adjust. Rules that prevent 90% of
"my script is missing" reports:

- A file not referenced by `default.project.json` never reaches Studio.
- Suffixes decide the class: `.server.luau` → `Script`, `.client.luau` →
  `LocalScript`, `.luau` → `ModuleScript`.
- Keep the sentinel script mapped (default `ServerScriptService.<Name>Boot`): it
  is how an agent proves the right repository is synced into the open session.

## 4. Pin the environment (devenv)

Copy `templates/devenv.nix` plus a `devenv.yaml` with
`nixpkgs: github:cachix/devenv-nixpkgs/rolling`, then commit `devenv.lock`.

Why this matters: it makes the toolchain identical for the user, for every AI
client, and in CI, and it stops "works on my machine" drift. Verify with
`devenv shell -- command -v rojo` and `devenv test`.

Do **not** rely on a global install alone; the repo must carry its own pins.

## 5. First build and first connection

1. `rojo build default.project.json -o place/<game>.rbxlx` — the place file is a
   build artefact you then track.
2. Open it in Studio as a **local** place (`--task EditFile --localPlaceFile`).
3. In Studio: Plugins → Rojo → Connect. Studio must have been started **after**
   the plugin was installed (§ gotchas 1).
4. Verify with the handshake in `references/studio-sync.md` before touching code.

## 6. Daily loop (state this back to the user)

```
edit src/*.luau  →  Rojo pushes to Studio  →  playtest + console  →  save_place
                 →  git commit/push          →  GitHub
```

Geometry: edit in Studio → `save_place` writes the tracked `.rbxlx` → commit.
Scripts: edit files, never Studio.

## 7. Sync gesture (cautious default, autosync on request)

Use `git HEAD` as the last-synced baseline and compare three snapshots. The full
table and the halt conditions are in `references/studio-sync.md`; the short form:

- files changed, Studio clean → push already happened via Rojo; commit.
- Studio changed, files clean → show the diff, ask, then write the file.
- both changed differently → **halt**, print both diffs, never choose.

Autosync applies only the unambiguous rows and still halts on the last one.

## 8. Publish

Gate publishing behind an explicit request and a clean tree. Either Studio's
*Publish to existing experience*, or `rojo upload --api_key … --universe_id …
--asset_id …`. Details and secrets handling: `references/ci-and-publish.md`.

## 9. CI

Copy `templates/ci.yml`. It lints, checks formatting, builds the place and
uploads it as an artifact. CI cannot run gameplay tests: `--task RunScript` needs
a signed-in Studio. Say so instead of pretending.

## 10. Recovery

If anything is unclear, follow `references/gotchas.md` top to bottom, then the
handshake in `references/studio-sync.md`. Never "fix" a bridge by deleting files.
