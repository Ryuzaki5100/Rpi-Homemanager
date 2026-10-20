---
name: tui-bubble-tea-creator
description: Deep reference playbook for building Go TUIs with Bubble Tea, Bubbles, and Lip Gloss (vim keys, Elm architecture, staged build, devenv/Nix, packaging). Loaded on demand by the tui-bubble-tea-creator SKILL.md router.
---

# Bubble Tea TUI (Go, vim keys)

Build TUIs that are easy to extend: strict Elm architecture, one keymap source of truth, layout computed in one place, async work only through `tea.Cmd`.

> This is the deep reference for the `tui-bubble-tea-creator` skill. The router and the
> always-on core rules live in `SKILL.md`; read them first, then use this file for detail.

## 0. Before writing code

1. **Pin the stack.** Read `go.mod` if it exists. Otherwise run `go list -m -versions github.com/charmbracelet/bubbletea` (or check the Charm docs) and pick the current stable major. Do not mix v1 and v2 import paths or APIs. Pin Bubbles and Lip Gloss to versions compatible with the chosen Bubble Tea. If you cannot verify an API, check the package source or `go doc` rather than guessing.
2. **Get the spec.** If the user has not provided these, ask once (batched), and propose defaults for anything unanswered:
   - Purpose and the data each pane shows
   - Layout sketch (ASCII is fine) or a reference app ("like lazygit")
   - State model: entities, where data comes from (files, HTTP, DB, subprocess)
   - Any keybindings beyond the standard vim set below
   - Behavior on resize, empty, loading, error
3. **Restate the plan** in a few lines: layout, models, messages, stages. Then build.

## 1. Architecture rules

- Elm style: `Model` holds state, `Update(msg) (Model, Cmd)` mutates state, `View()` is pure rendering. No I/O, sleeping, or goroutines in `Update` or `View`.
- All I/O is a `tea.Cmd` that returns a typed message (`itemsLoadedMsg`, `errMsg`). Use `tea.Batch` and `tea.Sequence` deliberately.
- **Stale results:** tag requests with an ID or generation counter and drop responses that do not match. Support cancellation with `context.Context` where requests can pile up.
- **Root model + child models.** The root owns window size, focus, mode, and routing. Each pane is its own model with `Update`, `View`, and `SetSize(w, h)`. Children return commands; they never call into siblings. Cross-pane communication goes through messages.
- Prefer value receivers for models, and always return the updated model. Do not hold pointers to child models in two places.
- Keep domain logic (parsing, filtering, sorting) in plain Go packages with no Bubble Tea imports, so it is unit-testable.

### Layout of a project

```
cmd/<app>/main.go        # wiring only
internal/app/            # root model, routing, mode handling
internal/ui/<pane>/      # one package per pane or widget
internal/ui/keys/        # keymap, help.KeyMap implementations
internal/ui/styles/      # Lip Gloss styles and theme
internal/domain/         # pure logic, no TUI imports
internal/data/           # I/O: files, HTTP, DB (called from Cmds)
```

Small apps can flatten this, but keep keys, styles, and domain separate.

## 2. Vim keybindings

Define every binding once with `bubbles/key` and expose it through `help.KeyMap` so the footer and `?` overlay are generated, never hand-written.

### Default keymap (implement unless told otherwise)

| Scope | Keys | Action |
|---|---|---|
| Move | `j` `k` / `↓` `↑` | next / previous item |
| Pane focus | `h` `l` / `ctrl+w` + `h/j/k/l` | move focus between panes |
| Jump | `gg` / `G` | top / bottom |
| Page | `ctrl+d` / `ctrl+u`, `ctrl+f` / `ctrl+b` | half / full page |
| Counts | `5j`, `12G` | numeric prefix repeats or targets |
| Search | `/` then text, `enter`; `n` / `N` | search, next / previous match |
| Command | `:` then `q`, `w`, `help`, app commands | command line |
| Select | `space` toggle, `v` visual range, `esc` clear | multi-select |
| Open / back | `enter` or `l` / `h` or `backspace` | drill in / out |
| Actions | `dd` delete, `yy` yank, `o` new, `r` refresh | app-defined, confirm destructive ones |
| Help | `?` | toggle full help overlay |
| Quit | `q` (normal mode), `ctrl+c` always | quit |

### Modes

Use an explicit `mode` enum on the root model: `ModeNormal`, `ModeInsert` (text input focused), `ModeSearch`, `ModeCommand`, optionally `ModeVisual`. Rules:

- In Normal mode, keys are commands. In Insert, Search, and Command modes, route keys to the focused `textinput`/`textarea` first.
- `esc` always returns to Normal and clears pending input. `ctrl+c` always quits (or cancels the current operation first if one is running).
- Show the mode and any pending keys in the status bar, for example `-- NORMAL --`, `-- INSERT --`, `2d`.

### Multi-key sequences and counts

Handle `gg`, `dd`, `yy`, `ctrl+w h`, and numeric prefixes with a small input buffer on the root model:

```go
type pending struct {
    count int      // 0 means "no count"
    keys  []string // e.g. ["g"], ["d"], ["ctrl+w"]
    gen   int      // bump on every key; used to expire the buffer
}

type pendingExpiredMsg struct{ gen int }

func expireAfter(gen int, d time.Duration) tea.Cmd {
    return tea.Tick(d, func(time.Time) tea.Msg { return pendingExpiredMsg{gen} })
}
```

On each keypress in Normal mode: digits (except a leading `0`) extend the count; a sequence starter (`g`, `d`, `y`, `ctrl+w`) pushes onto `keys` and returns `expireAfter(gen, ~800ms)`; a completing key resolves the sequence, runs the action `max(count,1)` times, and clears the buffer. A `pendingExpiredMsg` whose `gen` is stale is ignored. Unknown completion clears the buffer silently.

### Keymap sketch

```go
type KeyMap struct {
    Up, Down, Left, Right key.Binding
    Top, Bottom           key.Binding
    HalfUp, HalfDown      key.Binding
    Search, Command       key.Binding
    NextMatch, PrevMatch  key.Binding
    Help, Quit            key.Binding
}

func (k KeyMap) ShortHelp() []key.Binding  { return []key.Binding{k.Down, k.Up, k.Search, k.Help, k.Quit} }
func (k KeyMap) FullHelp() [][]key.Binding { /* group by Move / Search / Actions / App */ return nil }
```

Always define the arrow-key alternates in the same binding as the vim key (`key.WithKeys("j", "down")`). Use `key.Matches(msg, km.Down)` in `Update`, never raw string comparisons scattered around.

## 3. Layout, sizing, resize

- Handle `tea.WindowSizeMsg` in the root only. One function, `layout()`, computes every pane's width and height from the terminal size, then calls `SetSize` on each child. Do not compute sizes inside `View()`.
- Subtract frame sizes using `style.GetFrameSize()` or `GetHorizontalFrameSize()` / `GetVerticalFrameSize()` instead of hardcoding border and padding numbers.
- Compose with `lipgloss.JoinHorizontal` / `JoinVertical`. Always give panes explicit `Width`/`Height` (or `MaxWidth`/`MaxHeight`) so content cannot overflow and shove the footer off-screen.
- Layout is: body panes, then one status/mode line, then a help footer. Reserve their heights first, give the remainder to the body.
- **Minimum size guard:** if the terminal is smaller than the layout can handle, render a centered "terminal too small (need WxH)" message instead of a broken layout.
- Truncate with `ansi.Truncate` or `lipgloss` width helpers (they are ANSI- and wide-rune-aware); never slice strings by byte or `len`.
- Use `bubbles/viewport` for scrolling text and `bubbles/list` or `bubbles/table` for collections unless you need behavior they cannot provide. If you wrap them, make sure their built-in keymaps do not conflict with yours: disable or rebind their keys explicitly.

## 4. States every pane must handle

- **Loading:** `bubbles/spinner` or a progress bar, driven by messages.
- **Empty:** a helpful message ("No items. Press `o` to add one.").
- **Error:** show the error in the pane or status bar, keep the app usable, offer retry (`r`). Never `log.Fatal` or panic from `Update`.
- **Resize:** content reflows; selection and scroll offset stay valid (clamp the cursor after any data or size change).
- **Destructive actions:** confirm in a small modal or command-line prompt (`y/n`).

## 5. Styling

- Centralize colors and styles in `internal/ui/styles`. Use `lipgloss.AdaptiveColor` (or the current equivalent for the pinned version) so light and dark terminals both work.
- Never rely on color alone for meaning (selection, errors): add a marker such as `>` or a prefix.
- Highlight the focused pane with a distinct border color; dim unfocused ones.
- Respect `NO_COLOR` and degrade gracefully on limited terminals.

## 6. Staged build (stop and verify after each stage)

1. **Skeleton:** reproducible environment first (section 10: `devenv.nix`, `flake.nix`, `.envrc`, `justfile`), then module init, `main.go`, root model, quit keys, window size handling, layout with placeholder panes, status line, help footer. Verify: `devenv shell -- go build ./... && go vet ./...` (or plain `go` for non-Nix users), runs, resizes cleanly, `nix build` succeeds.
2. **Navigation:** keymap, modes, `j/k/gg/G`, counts, pane focus, `?` help. Verify: unit tests for the pending-key buffer and cursor clamping.
3. **Data:** domain types, real or mock data source, `tea.Cmd` loading with spinner, empty and error states, stale-response guard.
4. **Features:** search, command mode, selection, actions, modals.
5. **Polish:** theme, edge cases, tiny-terminal behavior, README with a keybinding table, `go test ./...`, `golangci-lint` if available.

Do not generate everything in one pass. After each stage, summarize what exists and what the next stage will add. If the user's request is small, collapse stages but keep the order.

## 7. Testing

- Test `Update` as a function: feed `tea.KeyMsg` / custom messages, assert on the returned model and command.
- Use `github.com/charmbracelet/x/exp/teatest` for end-to-end flows with a fixed terminal size, and golden files for `View()` output of stable screens.
- Test domain packages with ordinary table-driven tests.
- Provide a `--demo` or fake data source flag so the UI can be exercised without real backends.

## 8. Common mistakes to avoid

- Blocking in `Update` (HTTP, disk, `time.Sleep`). Use Cmds.
- Mutating shared slices or maps from a Cmd goroutine. Return data in a message and apply it in `Update`.
- Forgetting to forward messages to children (especially `WindowSizeMsg`, spinner ticks, and blink messages) and to collect and batch their returned Cmds.
- Letting a focused `textinput` swallow `esc` or `q` in the wrong mode, or letting `q` quit while typing.
- Hardcoded sizes, byte-based truncation, unconditional `tea.WithAltScreen` without restoring the terminal on panic (use `defer` and keep `main` returning errors).
- Logging to stdout. Use `tea.LogToFile("debug.log", "")` and tail it in another terminal.
- Duplicating keybinding documentation instead of generating it from the keymap.

## 9. Output expectations

- Complete, compiling code per stage, with file paths shown. No `// TODO: implement` stubs in delivered stages.
- Idiomatic Go: wrapped errors with `%w`, small interfaces at package boundaries, `gofmt`-clean.
- Stage 1 also delivers the environment files from section 10. After any `go.mod` change, remind the user to refresh `vendorHash`.
- End each stage with: how to run it, the keys available so far, and what the next stage adds.

## 10. Dev environment and easy setup

Goal: anyone can clone the repo and be running in one command, with or without Nix. Nix is the primary path; everything else is a convenience layer on top of the same `go.mod`.

**Rules**
- All tooling (Go toolchain, linters, release tools, demo recorders) comes from Nix. Never tell the user to `brew install` or `apt install` a dev dependency in a Nix project. Go libraries stay in `go.mod`.
- Commit `devenv.nix`, `devenv.yaml`, `devenv.lock`, `flake.nix`, `flake.lock`, `.envrc`, and `justfile`. Ignore `.devenv/` and `.direnv/`.
- Devenv and Nix options change between releases. Check the current devenv docs (devenv.sh) before using an option; do not assume names from memory (for example, git hook options have been renamed before).
- Keep the Go version in one place (`devenv.nix` and `go.mod`) and make them agree.

### devenv (dev shell)

`devenv.nix`:

```nix
{ pkgs, ... }: {
  languages.go.enable = true;

  packages = with pkgs; [
    golangci-lint
    gotools        # goimports etc.
    gopls
    delve
    just
    goreleaser
    vhs            # record demo GIFs from a .tape file
  ];

  env.CGO_ENABLED = "0";

  scripts.run.exec = "go run ./cmd/APP \"$@\"";
  scripts.demo.exec = "go run ./cmd/APP --demo";

  enterTest = ''
    go vet ./...
    go test ./...
  '';

  # Verify current option names in the devenv docs before enabling.
  git-hooks.hooks = {
    gofmt.enable = true;
    govet.enable = true;
    golangci-lint.enable = true;
  };
}
```

`devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
```

`.envrc` (auto-activates the shell with direnv; use the line the current devenv docs specify):

```
use devenv
```

Workflow: `devenv init` (or the files above), `direnv allow` or `devenv shell`, then `devenv test` to run `enterTest`. Add a `.gitignore` entry for `.devenv*` and `.direnv`.

### flake.nix (package, `nix run`, `nix profile`)

Expose the app as a package so users can run it without cloning:

```nix
{
  description = "APP: a Bubble Tea TUI";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAll (pkgs: {
        default = pkgs.buildGoModule {
          pname = "APP";
          version = self.shortRev or self.dirtyShortRev or "dev";
          src = ./.;
          vendorHash = null; # replace: build once with pkgs.lib.fakeHash, copy the real hash from the error
          subPackages = [ "cmd/APP" ];
          ldflags = [ "-s" "-w" ];
          meta.mainProgram = "APP";
        };
      });

      apps = forAll (pkgs: {
        default = {
          type = "app";
          program = pkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell { packages = [ pkgs.go pkgs.gopls pkgs.golangci-lint ]; };
      });
    };
}
```

Notes:
- `vendorHash = null` is only correct when the repo vendors dependencies (`go mod vendor`). Otherwise set `pkgs.lib.fakeHash`, run `nix build`, and paste the hash from the error. Update it whenever `go.mod` or `go.sum` changes (add a `just nix-hash` helper or a CI check).
- The `devShells.default` is a fallback for people who use flakes but not devenv. Keep it minimal and consistent with `devenv.nix`.
- What users then get: `nix run github:OWNER/APP`, `nix profile install github:OWNER/APP`, or `nix build && ./result/bin/APP`. For NixOS and Home Manager users, show the flake input plus `environment.systemPackages` / `home.packages` snippet in the README.
- If you want to stay purely on devenv's own build support, check the devenv docs for its Go outputs and keep the flake package anyway for `nix run`.

### justfile (one command surface for everyone)

```make
default: run

run *args:
    go run ./cmd/APP {{args}}

demo:
    go run ./cmd/APP --demo

test:
    go test ./...

lint:
    golangci-lint run

build:
    go build -trimpath -ldflags "-s -w -X main.version=$(git describe --tags --always --dirty)" -o bin/APP ./cmd/APP

nix-build:
    nix build

tape:
    vhs demo.tape
```

Prefer `just` over a Makefile unless the user asks otherwise (simpler syntax, cross-platform). Inside the devenv shell these run the Nix-provided tools.

### Non-Nix paths (for people who will not use Nix)

Provide all of these in the README, with copy-pasteable commands:

1. **`go install github.com/OWNER/APP/cmd/APP@latest`** (requires only Go; works if `main` is under `cmd/APP`).
2. **Prebuilt binaries** via GoReleaser and GitHub Releases for linux/darwin/windows on amd64 and arm64. Add `.goreleaser.yaml` and a release workflow triggered by tags.
3. **Homebrew tap** through GoReleaser's `brews` section (check the current GoReleaser docs for the key name; it has changed over time).
4. **Container image** (optional): multi-stage Dockerfile ending in a `scratch` or distroless image, run with `docker run -it --rm`. Needs `-it` for a TUI.
5. **Plain clone and build:** `git clone … && just build`, or `go run ./cmd/APP`.

### CI (GitHub Actions)

- Job 1: install Nix (for example `DeterminateSystems/nix-installer-action`, or the current recommended action), then `nix build` and `nix flake check`. Optionally use a Nix cache action to speed up runs.
- Job 2: `go vet`, `go test ./...`, `golangci-lint` on a Go version matrix, on ubuntu and macos.
- Release job: GoReleaser on tag push.
- Pin action versions. Fail CI if `vendorHash` is stale (the Nix build catches it).

### Make the app itself easy to adopt

- Flags: `--version`, `--help`, `--demo` (fake data, no setup), `--config <path>`, `--no-color`.
- Config: respect XDG (`$XDG_CONFIG_HOME/APP/config.toml`, fall back to `~/.config/APP`), with sane defaults so a missing config is not an error. Write the default config on request (`APP --print-config`).
- Keymap overrides in config, so users can remap vim keys without recompiling.
- Works over SSH and inside tmux/screen: no reliance on mouse-only features, tolerate `TERM` limitations, handle a non-TTY stdout with a clear error.
- Optional: `APP completion bash|zsh|fish` if using Cobra, and `vhs` tape to generate the README demo GIF.
- README must open with: a demo GIF, the three fastest install commands (`nix run`, `go install`, brew), a keybinding table (generated from the keymap), and a "Development" section showing `direnv allow` or `devenv shell`, `just test`, `just run`.

## Appendix: intake template (user fills in per project)

```
Project:      <name and one-line purpose>
Go / deps:    <Go version; Bubble Tea major version if you care>
Data source:  <files / API / DB / subprocess, with sample shape>
Layout:       <ASCII sketch or "like <app>">
Panes:        <name: what it shows, what selecting does>
Extra keys:   <app-specific bindings>
Commands:     <":" commands, if any>
Constraints:  <min terminal size, platforms, no network, etc.>
Distribution: <nix run / go install / Homebrew / release binaries / Docker; default: all but Docker>
Env:          <devenv + direnv (default), plain flake devShell, or none>
```
