---
name: roblox-git-bridge
description: Attaching an existing project to a GitHub repository, plus what to commit and what to ignore in a Roblox project.
---

# Attaching the repository

## Empty remote (the common case)

```sh
git -C <dir> remote add origin <url>   # if missing
git -C <dir> ls-remote origin          # empty output = nothing to merge
git -C <dir> add -A
git -C <dir> commit -m "feat: scaffold <game> with Rojo"
git -C <dir> push -u origin main
```

Verify afterwards: `git ls-remote --heads origin` shows the commit hash you just
pushed. Do not report success from `git push` output alone.

## Remote already has commits

Stop and inspect before merging:

```sh
git fetch origin
git log --oneline origin/main -5
git ls-tree -r --name-only origin/main | head -50
```

- Disjoint content (a README only) → `git pull --rebase origin main`, then push.
- Same files, different content → do not merge blindly. Show both sides and ask.
- Never `push --force`, never delete the remote's commits.

## What to commit

| Commit | Ignore |
|---|---|
| `src/**` | `build/` |
| `place/*.rbxlx` (XML, diffable) | `*.rbxl` (binary) |
| `default.project.json`, `roblox.json` | `sourcemap.json` |
| `devenv.nix`, `devenv.yaml`, `devenv.lock` | `globalTypes.d.luau` |
| `selene.toml`, `stylua.toml`, `.luaurc` | `.devenv/`, `.direnv/` |
| `AGENTS.md`, `docs/` | secrets, API keys, cookies |

`.gitattributes`:

```
*.rbxlx text eol=lf
*.rbxl binary
*.luau text eol=lf
```

Large binary assets (audio, meshes) should go to Roblox as assets, not into git.
If a repository truly needs blobs, use Git LFS for those extensions specifically.

## Tooling note

`gh` is convenient but not required: if the user already created the repository,
plain `git` is enough. Only reach for `gh repo create` when the user asks for it,
and confirm the visibility first.
