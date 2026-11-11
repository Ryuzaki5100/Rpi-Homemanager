---
name: roblox-git-bridge
description: Ten Roblox/Rojo/devenv/nix failures that cost real debugging time, with the evidence that identifies each one and the fix.
---

# Gotchas that cost real time

Each entry was hit in a real session. The "evidence" line is how to confirm the
diagnosis instead of guessing.

## 1. Studio only scans plugins at startup

Installing the Rojo plugin while Studio is running produces no button and no
error. The plugin simply does not exist for that process.

- Evidence: `ps -o lstart= -p <Studio pid>` is **earlier** than the plugin file's
  `stat` mtime.
- Fix: quit Studio with `Cmd+Q` (closing windows is not enough), reopen.
- If it is still missing after a restart: Plugins → Manage Plugins → Plugins
  Folder, confirm it matches `~/Documents/Roblox/Plugins`; then check
  System Settings → Privacy & Security → Files and Folders → Roblox Studio has
  Documents access.

## 2. `enterTest` is inert in devenv 2.4

Declaring `enterTest = ''…''` leaves the task with **no command**:
`devenv test` reports success while running nothing.

- Evidence: `devenv tasks list` shows `devenv:enterTest (no command)`.
- Fix: `tasks."devenv:enterTest".exec = ''…'';` — verify the "(no command)"
  suffix disappears before trusting a green run.

## 3. `rojo serve` and `devenv up` fight over port 34872

Only one process can own the port; the second dies with "address already in use".

- Evidence: `lsof -nP -iTCP:34872 -sTCP:LISTEN` shows an existing PID.
- Fix: use one. `devenv up` is the managed path; stop with `devenv down`.

## 4. Launching Studio twice for one place

`open -a RobloxStudio file.rbxlx` forwards the file through the protocol handler;
running the binary with `--task EditFile --localPlaceFile` does the same. Doing
both gives one instance that owns the file and another stuck at "Place is not
open".

- Evidence: `list_roblox_studios` returns an extra entry with
  `mode: "Unavailable"`, `name: null`, `state: "Place is not open"`.
- Fix: launch once. Treat `Unavailable` entries as stray windows and ignore them;
  never target them.

## 5. Rojo silently overwrites Studio-side script edits

Rojo has **no conflict detection**. While connected, any file change replaces the
Studio copy; an unsaved Studio edit disappears without a warning.

- Evidence: edit a script in Studio, then touch the file — `script_read` returns
  the file's content and the Studio edit is gone.
- Consequence: scripts are edited in files. The "Studio → files" direction exists
  only for a deliberate, diffed syncback (or when the plugin is disconnected).

## 6. `save_place` writes to disk only for local places

| Place type | `save_place` result |
|---|---|
| local `.rbxl` / `.rbxlx` | writes the file on disk → git sees it |
| cloud place | creates a cloud version → git never sees it |

- Consequence: the tracked **local** place is canonical; the cloud place is a
  publish target. This is the single most important architectural decision.

## 7. A local place has no `placeId`

`list_roblox_studios` returns `persistedToCloud: false` and a `file` field
instead. Matching a local session by `placeId` fails forever.

- Fix: cloud → match `placeId`; local → match `file`; then confirm the sentinel
  script exists. Window titles are not proof.

## 8. `wally` is unavailable on Apple Silicon nixpkgs

`wally` is marked `badPlatforms = [ "aarch64-darwin" ]`. Adding it to a package
list fails the build.

- Evidence: `nix eval … pkgs.wally.meta.badPlatforms`.
- Fix: leave it out; pin its prebuilt darwin release per project if a package is
  ever needed.

## 9. Studio-side console noise that is not your code

Observed in every playtest, in both a template cloud place and a clean place
built from a Rojo project:

```
cloud_3104443226.S^X | v1.4.1b:26: attempt to index nil with 'WaitForChild'
ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type
```

- Evidence it is not project content: scanning every instance property for that
  asset id returns zero matches; the script list contains only project scripts.
- Fix: ignore, or report once with the Studio MCP `submit_feedback` tool. Do not
  "clean up" anything in the repository to chase it.

## 10. A path flake ignores untracked files

`home-manager switch --flake .#…` (and any `nix build` on a path flake) only
sees files that git knows about. A newly created skill, module or script is
invisible until it is added, and the error is a bare "path is not tracked by
Git" — or worse, a silent no-op.

- Evidence: `nix` warns `Path '…' in the repository '…' is not tracked by Git`.
- Fix: `git add -N <path>` (or commit) before switching. Never conclude the
  module is broken before checking `git status`.

## Meta-rule

When two explanations fit, prefer the one with evidence you can reproduce in one
command. Every item above was originally misdiagnosed as "the code is broken".
