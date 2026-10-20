---
name: tui-bubble-tea-creator
description: Builds a complete Go terminal UI (TUI) project with Bubble Tea, Bubbles, and Lip Gloss from a specification. The user supplies the spec either as a path to a markdown file describing the application in detail or inline in the prompt. Produces a staged, compiling project (Elm architecture, vim keybindings, layout/resize, loading/empty/error states, tests, devenv/Nix, packaging, CI). Use whenever the user wants a TUI, terminal app, curses-style interface, or mentions bubbletea, bubble tea, lipgloss, bubbles, or charm in Go — even if they don't say "skill" or give a full spec. Also use when extending, refactoring, or debugging an existing Bubble Tea project.
---

# TUI Bubble Tea Creator

Build terminal UIs in Go that are easy to extend. Every detailed rule — architecture, keymap,
layout, styling, testing, dev environment, packaging — lives in `GUIDE.md`. This file is the
router: it tells you what to do in what order and where to look.

## Step 0 — Read the reference first (mandatory)

Before writing **any** code, read `GUIDE.md` from this skill's base directory and treat it as
authoritative:

```
read <skill-base-dir>/GUIDE.md
```

The core rules below are inlined so a skipped reference degrades gracefully, but the depth
(stack pinning, the pending-key buffer, `teatest`, devenv/flake, GoReleaser, CI) is only in
`GUIDE.md`. Do not guess an API; verify against the package source or `go doc`.

## Core rules (always apply)

1. **Elm architecture.** `Model` holds state; `Update(msg) (Model, Cmd)` mutates state; `View()`
   is pure rendering. No I/O, sleeping, or goroutines in `Update` or `View`.
2. **All I/O is a `tea.Cmd`** that returns a typed message (`itemsLoadedMsg`, `errMsg`). Use
   `tea.Batch`/`tea.Sequence` deliberately. Tag requests with an ID/generation and drop stale
   responses; support cancellation with `context.Context`.
3. **One keymap source of truth.** Define every binding once with `bubbles/key` and expose it via
   `help.KeyMap`; the footer and `?` overlay are generated, never hand-written. Match with
   `key.Matches`, never raw string comparisons. Always pair the vim key with its arrow alternate
   (`key.WithKeys("j", "down")`).
4. **Layout in one place.** Handle `tea.WindowSizeMsg` in the root only; one `layout()` computes
   every pane size and calls `SetSize`. Never compute sizes in `View()`. Subtract frames with
   `style.GetFrameSize()`, compose with `lipgloss.JoinHorizontal`/`JoinVertical`, truncate with
   `ansi.Truncate`/lipgloss helpers (never byte-slice).
5. **Root + child models.** The root owns window size, focus, mode, and routing. Each pane is a
   child model with `Update`/`View`/`SetSize`; children never call siblings — cross-pane traffic
   goes through messages. Keep domain logic in plain Go packages with no Bubble Tea imports.
6. **Every pane handles** loading (`bubbles/spinner`), empty (helpful hint), error (shown, app
   stays usable, offer retry `r`), resize (clamp cursor/scroll after data or size change), and
   destructive actions (confirm `y/n`). Guard a minimum terminal size.
7. **Never panic or `log.Fatal` from `Update`; never log to stdout** (use `tea.LogToFile`). Quit
   keys `q` (normal mode) and `ctrl+c` (always); `esc` always returns to Normal and clears input.
8. **Staged, stop-and-verify build.** Do not emit everything in one pass. Complete a stage, run
   its checks, summarize, then continue.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Gather spec fields, pin the stack, and restate the plan | `GUIDE.md` §0 | Intake checklist, version pinning |
| Design the package layout and enforce Elm rules | `GUIDE.md` §1 | Architecture + project layout |
| Implement keybindings, modes, `gg`/`dd`/counts | `GUIDE.md` §2 | Vim keymap spec + pending buffer |
| Compute layout, resize, minimum-size guard | `GUIDE.md` §3 | Sizing rules |
| Handle loading/empty/error/resize/destructive states | `GUIDE.md` §4 | Pane state contract |
| Theme, adaptive colors, focus highlighting | `GUIDE.md` §5 | Styling |
| Run the staged build in order | `GUIDE.md` §6 | Stage-by-stage checklist |
| Write `Update`/E2E/golden tests | `GUIDE.md` §7 | Testing |
| Avoid known pitfalls | `GUIDE.md` §8 | Common mistakes |
| Meet output expectations per stage | `GUIDE.md` §9 | Deliverables |
| devenv / flake / justfile / CI / packaging | `GUIDE.md` §10 | Dev environment & distribution |
| Fill a per-project intake form | `GUIDE.md` Appendix | Intake template |

## Workflow

### 1. Get the spec
- If the prompt gives a **path**, `read` it and extract: purpose, panes, data source, layout,
  extra keys, commands, constraints, distribution, env.
- If the spec is **inline**, use the prose as-is.
- If key fields are missing, ask **one batched `question`** (per the `GUIDE.md` Appendix) and
  propose defaults for anything unanswered. Never stall waiting for perfect input.

### 2. Restate the plan
In a few lines: layout (ASCII ok), child models, messages, and the stages you will build. Then
proceed.

### 3. Build in stages (stop and verify after each)
Follow `GUIDE.md` §6 in order. After each stage: run its checks, tell the user how to run it, the
keys available so far, and what the next stage adds.

1. **Skeleton + env** — devenv/flake/`.envrc`/justfile, module init, `main.go`, root model, quit
   keys, window-size handling, placeholder panes, status line, help footer.
   Verify: `go build ./... && go vet ./...`, runs, resizes cleanly, `nix build` succeeds.
2. **Navigation** — keymap, modes, `j/k/gg/G`, counts, pane focus, `?` help.
   Verify: unit tests for the pending-key buffer and cursor clamping.
3. **Data** — domain types, data source, `tea.Cmd` loading with spinner, empty/error states,
   stale-response guard.
4. **Features** — search, command mode, selection, actions, modals.
5. **Polish** — theme, edge cases, tiny-terminal behavior, README keybinding table,
   `go test ./...`, `golangci-lint`.

### 4. Validate before declaring done
- `gofmt`-clean, `go vet ./...`, `go test ./...` pass; `golangci-lint run` if available.
- No `// TODO: implement` stubs in delivered stages.
- Every keybinding is generated from the keymap, not duplicated in prose.
- After any `go.mod` change, remind the user to refresh `vendorHash`.

## Tools

`read` (spec + `GUIDE.md`), `write`/`edit` (code and config), `bash` (`go`, `just`, `nix`,
`golangci-lint`), `glob`/`grep` (explore an existing project), `question` (batched intake).
