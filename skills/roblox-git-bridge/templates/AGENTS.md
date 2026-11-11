# AGENTS.md

Operating contract for this repository.

## Identity

`roblox.json` is the single source of truth: repo name, game name, tracked place
file, optional placeId/universeId, and the sentinel script. The repository name
and the game name are independent — never derive one from the other.

## Files are the source of truth

- Luau lives in `src/` and is mapped by `default.project.json` via Rojo.
- Geometry lives in the tracked `place/*.rbxlx`. Only a **local** place writes to
  disk on save; a cloud place does not.
- A change that exists only in an open Studio session does not exist.

## Commands

| Task | Command |
|---|---|
| Enter the pinned environment | `devenv shell` |
| Start live sync | `devenv up` (never alongside `rojo serve`) |
| Lint + format check + build | `devenv test` |
| Open the tracked place | `studio-open` (`--cloud` for the published one) |
| Git state | `status` |
| Pull / commit / push | `sync.sh -m "message"` |
| Health check | `preflight` |

## Studio rules

1. Match the session by `placeId` (cloud) or `file` (local), then confirm the
   sentinel script exists.
2. Scripts are edited in files. Rojo overwrites Studio-side script edits silently.
3. Divergence is decided against `git HEAD`; two-sided divergence halts.
4. Launch Studio once per place; ignore `Unavailable` MCP entries.
5. Never force-push, never `reset --hard`, never delete files you did not create.

## Committing

Commit `src/` and `place/` together when a change spans both. Keep `build/`,
`sourcemap.json`, `globalTypes.d.luau` and binaries out of history. Never commit
API keys or cookies.
