# dotfiles

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos&logoColor=white)](https://nixos.org)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-25.11-green?logo=nixos&logoColor=white)](https://github.com/nix-community/home-manager)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Arch](https://img.shields.io/badge/arch-aarch64--linux%20%7C%20aarch64--darwin-red)](#)

Personal Home Manager configuration for a terminal-centric workflow, shared across `aarch64-linux` (Raspberry Pi 5) and `aarch64-darwin` (Apple Silicon). `x86_64-linux` is supported structurally by the module tree but is not currently exercised by a machine. This flake manages user-level packages, shell configuration, environment variables, and Obsidian TUI tooling — all without any system-level configuration.

## Table of Contents

- [Architecture](#architecture)
- [Structure](#structure)
- [Modules](#modules)
  - [Platform layers](#platform-layers)
  - [core.nix](#corenix)
  - [env.nix](#envnix)
  - [fish.nix](#fishnix)
  - [opencode.nix](#opencodenix)
  - [packages.nix](#packagesnix)
  - [gmail-mcp.nix](#gmail-mcpnix)
  - [firecrawl.nix](#firecrawlnix)
  - [immich.nix](#immichnix)
  - [filebrowser.nix](#filebrowsernix)
  - [obsidian.nix](#obsidiannix)
  - [ghostty.nix](#ghosttynix)
  - [opencode-lmstudio.nix](#opencode-lmstudionix)
  - [roblox.nix](#robloxnix)
  - [glow.nix](#glownix)
  - [epub.nix](#epubnix)
  - [retrocrt.nix](#retrocrtnix)
- [Skills](#skills)
- [Custom Packages](#custom-packages)
  - [nixvim-editor](#nixvim-editor)
  - [dripfetch](#dripfetch)
  - [archify](#archify)
  - [bitchat-cli](#bitchat-cli)
  - [gmail-mcp-auth](#gmail-mcp-auth)
  - [obsitui](#obsitui)
  - [retrocrt](#retrocrt)
- [Quick Start](#quick-start)
  - [macOS Support](#macos-support)
  - [Roblox Studio Setup](#roblox-studio-setup)
  - [Gmail MCP Setup](#gmail-mcp-setup)
  - [Firecrawl Setup](#firecrawl-setup)
  - [Tailscale Setup](#tailscale-setup)
  - [Immich Setup](#immich-setup)
  - [Samba Shares](#samba-shares)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)

## Architecture

```
flake.nix  ──►  home.nix  ──►  modules/default.nix
                      │              │
                      │              ├── common/          # builds on every platform
                      │              ├── linux/           # x86_64-linux + aarch64-linux
                      │              ├── linux-aarch64/   # Raspberry Pi 5 hardware
                      │              └── darwin/          # aarch64-darwin
                      │
                      ├── pkgs/
                      │     ├── archify.nix
                      │     ├── nixvim-editor.nix
                      │     ├── obsitui.nix
                      │     ├── gmail-mcp-auth.nix
                      │     ├── bitchat-cli.nix
                      │     └── retrocrt.nix
                      │
                      └── skills/
                            ├── ai-era-mock-interview/SKILL.md
                            ├── batch-resume-tailor/SKILL.md
                            ├── content-to-diagram/SKILL.md
                            ├── daily-prep-questions/SKILL.md
                            ├── glow-theme-creator/SKILL.md
                            ├── hld-problems-generator/SKILL.md
                            ├── job-grabber/SKILL.md
                            ├── job-search-resume-tailor/SKILL.md
                            ├── manga-merger/SKILL.md
                            ├── single-resume-tailor/SKILL.md
                            ├── skill-creator/SKILL.md
                            ├── system-design-tester/SKILL.md
                            ├── system-design-tutor/SKILL.md
                            ├── tui-bubble-tea-creator/SKILL.md
                            ├── update-docs/SKILL.md
                            └── yt-summarizer/SKILL.md
```

| Layer | Description |
|---|---|
| **`flake.nix`** | Entry point. Pins `nixpkgs` (nixos-unstable), `home-manager`, and the upstream `dripfetch` packaging flake. Builds custom packages per system (`packages.<system>` for `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`) and passes them as `extraSpecialArgs` into the module tree. `homeConfigurations.<user>` targets the current host and needs `--impure`; `homeConfigurations.<user>-<system>` gives an explicit, pure-safe target per platform. |
| **`home.nix`** | Thin shim; imports `modules/` and sets shared `nixpkgs.config`. |
| **`modules/default.nix`** | The single platform-selection point. Imports `common/` always, plus the matching platform layer(s) based on `pkgs.stdenv.hostPlatform`. |
| **`modules/common/`** | Modules and packages that build on **every** platform. |
| **`modules/linux/`, `linux-aarch64/`, `darwin/`** | Platform-specific packages and services (see [Platform layers](#platform-layers)). |
| **`pkgs/`** | Custom package derivations exported both as flake outputs and installed in the Home Manager profile. |
| **`skills/`** | OpenCode skill definitions. Each directory holds a router `SKILL.md` plus optional on-demand companions (`GUIDE.md`, `references/`, `scripts/`, `templates/`, `assets/`); the whole directory is deployed via `xdg.configFile` symlinks. |

### Dependencies

| Input | Source |
|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` |
| `home-manager` | `github:nix-community/home-manager` (follows `nixpkgs`) |
| `dripfetch` | `github:a-shygun/dripfetch?dir=packaging/nix` (follows `nixpkgs`; patched locally to exit cleanly on Ctrl+C) |
| `pebble` | `github:pebble-dev/pebble.nix` (supplies the builder expressions; the SDK core, toolchain, QEMU, and Python/Node deps are packaged locally) |

### Custom Packages as Flake Outputs

Custom packages are exposed under `packages.<system>` (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`), making them usable from outside this flake:

```bash
nix run github:Ryuzaki5100/dotfiles#obsitui
nix run github:Ryuzaki5100/dotfiles#nixvim-editor
nix run github:Ryuzaki5100/dotfiles#gmail-mcp-auth
nix run github:Ryuzaki5100/dotfiles#bitchat-cli
nix run github:Ryuzaki5100/dotfiles#archify
nix run github:Ryuzaki5100/dotfiles#retrocrt
nix run github:Ryuzaki5100/dotfiles#dripfetch
```

## Structure

```
dotfiles/
├── flake.nix              # Flake entry point, inputs, outputs
├── flake.lock             # Locked dependency revisions
├── home.nix               # Top-level Home Manager module
├── modules/
│   ├── default.nix         # Platform aggregator (common + host layer)
│   ├── common/             # Builds on every platform
│   │   ├── core.nix            # User identity, $HOME-driven home dir, state version
│   │   ├── env.nix            # Session environment variables
│   │   ├── epub.nix           # EPUB build tooling (epubcheck, fonts, python, fontconfig)
│   │   ├── filebrowser.nix    # Filebrowser options + package + DB bootstrap
│   │   ├── firecrawl.nix      # Firecrawl MCP server config
│   │   ├── fish.nix           # Fish shell config & aliases
│   │   ├── glow.nix           # glow markdown themes & glow-set-theme picker
│   │   ├── gmail-mcp.nix      # Gmail MCP auth packages
│   │   ├── immich.nix         # Immich compose + options (platform-parameterized)
│   │   ├── mangal.nix         # Mangal downloader config
│   │   ├── obsidian.nix       # Obsidian vaults & Basalt config
│   │   ├── opencode.nix       # OpenCode config, MCP settings & skill deployment
│   │   ├── rtk-opencode.ts    # Vendored RTK token-compression plugin (synced, do not edit)
│   │   ├── pebble.nix         # Pebble SDK/tool/QEMU wiring and SDK activation
│   │   ├── retrocrt.nix       # retrocrt CLI (CRT/VHS video styliser)
│   │   └── packages.nix       # Cross-platform package set
│   ├── linux/              # x86_64-linux + aarch64-linux
│   │   ├── filebrowser.nix    # systemd user unit
│   │   ├── immich.nix         # Enables the /etc/localtime bind-mount
│   │   ├── mounts.nix         # ~/hdd -> /mnt/hdd activation
│   │   └── packages.nix       # Linux-only package set
│   ├── linux-aarch64/      # Raspberry Pi 5 only
│   │   └── immich-hwaccel.nix # V4L2 decoder passthrough + HW transcode
│   └── darwin/             # aarch64-darwin
│       ├── filebrowser.nix    # launchd user agent
│       ├── ghostty.nix        # Ghostty terminal, Nerd Font & ghostty-set-theme picker
│       ├── opencode-lmstudio.nix # `opl`: opencode against loadable LM Studio models
│       ├── opl.py             # RAM-aware model/context selection + LM Studio lifecycle
│       ├── roblox.nix         # Roblox/Luau toolchain, Studio MCP wiring, luau-lsp wrapper
│       └── packages.nix       # macOS-only package set
├── glow/
│   └── themes/            # glamour v2 theme JSONs (retro-orange, gruvbox, nord, tokyo-night, catppuccin-mocha, dracula, blood-red)
├── pkgs/
│   ├── archify.nix        # Archify CLI + bundled authoring contract (upstream GitHub source)
│   ├── bitchat-cli.nix    # bitchat CLI (PyPI, buildPythonApplication)
│   ├── dripfetch-kbinterrupt.patch # Local patch: Ctrl+C exits dripfetch cleanly
│   ├── gmail-mcp-auth.nix # Wrapper around gmail-mcp-auth.py (python + google-auth-oauthlib)
│   ├── nixvim-editor.nix  # Thin wrapper around external Nixvim flake
│   ├── obsitui.nix        # Obsidian TUI from source (npm)
│   └── retrocrt.nix       # Wrapper pinning ffmpeg, Pillow and the timestamp font
├── scripts/
│   ├── add-subtitles.sh        # Embed an .srt into a video as a soft subtitle track
│   ├── backup-drive.sh        # Rotating hardlink snapshot backup of a mount
│   ├── build-epubs.sh         # Convert the ~/interview-prep markdown tree into EPUB books
│   ├── gmail-mcp-auth.py      # Headless OAuth helper for Gmail MCP
│   ├── init-filebrowser.sh    # One-shot reproducible Filebrowser setup (interactive password)
│   ├── init-home-manager.sh   # Bootstrap Home Manager on a fresh system
│   ├── install-nix.sh         # Install Nix with --daemon on a fresh system
│   ├── init-setup-hdd.sh     # Stop desktop auto-mount of the HDD; udev rule for /mnt/hdd
│   ├── init-setup-samba       # Samba setup (home, hdd, and ssd shares + recycle bin)
│   ├── opencode-gateway.py    # HTTP gateway proxy to opencode serve
│   ├── opencode-serve.sh      # Launch opencode serve and expose on tailnet
│   ├── download-vid.sh        # Download 4K video with yt-dlp and ffmpeg
│   ├── epub-preprocess.py     # Preprocess markdown (links, HTML tags, diagram fences) for pandoc
│   ├── retrocrt.py            # CRT/VHS video styliser (curved bezel, scanlines, timestamp)
│   ├── samba-recycle-restore.sh # Restore files from a Samba recycle bin
│   ├── setup-gmail-mcp.sh     # Interactive Gmail MCP setup wizard
│   ├── setup-firecrawl.sh     # Save a Firecrawl API key for the MCP server
│   ├── setup-immich.sh        # Bootstrap Docker daemon and start Immich
│   ├── setup-rpi-usb-gadget.sh # Configure RPi as USB ethernet gadget
│   ├── setup-tailscale.sh     # Tailscale auth, status check, and systemd enable
│   ├── setup-wayvnc.sh        # Set up WayVNC VNC server for iPad access
│   ├── sync-rtk-plugin.sh     # Vendor the upstream RTK OpenCode plugin matching the locked rtk
│   └── sync-to-ssd.sh         # Sync Immich albums to an external drive
└── skills/
    ├── ai-era-mock-interview/ # OpenCode skill: AI-era mock interview on a buggy Java/Maven codebase
    ├── batch-resume-tailor/ # OpenCode skill: batch tailor resumes from job posting URLs
    ├── content-to-diagram/ # OpenCode skill: turn content into one Archify HTML diagram
    ├── daily-prep-questions/ # OpenCode skill: daily no-repeat interview-prep set (LC/SD/behavioral/SQL/LLD)
    ├── glow-theme-creator/ # OpenCode skill: build glow themes from a described vibe
    ├── hld-problems-generator/ # OpenCode skill: synthesize HLD practice problems + EPUB
    ├── job-grabber/       # OpenCode skill: verified weekly job-intel run + resume dispatch
    ├── job-search-resume-tailor/ # OpenCode skill: audited, evidence-backed JD→resume tailoring
    ├── manga-merger/      # OpenCode skill: merge manga image folders into a fixed-layout EPUB
    ├── pebble-app/        # OpenCode skill: orchestrate a Pebble watchface/watchapp build
    ├── pebble-core/       # OpenCode skill: shared Pebble platform/docs/sample references
    ├── pebble-sdk-setup/  # OpenCode skill: Nix SDK, QEMU, and environment verification
    ├── pebble-project-scaffold/ # OpenCode skill: Pebble project metadata + skeleton
    ├── pebble-ui-design/  # OpenCode skill: pixel-accurate Pebble layout spec
    ├── pebble-c-dev/      # OpenCode skill: C watchfaces/watchapps
    ├── pebble-alloy-dev/  # OpenCode skill: Alloy (JS) watchfaces/watchapps
    ├── pebble-phone/      # OpenCode skill: PebbleKit JS + Clay
    ├── pebble-build-test/ # OpenCode skill: build, emulator, screenshot QA
    ├── pebble-release/    # OpenCode skill: icons, GIF, store publishing
    ├── single-resume-tailor/ # OpenCode skill: ATS-optimized one-page resume from a JD
    ├── roblox-git-bridge/ # OpenCode skill: attach a Roblox game to a git repo and keep it in sync
    ├── skill-creator/     # OpenCode skill: interactive skill creation wizard (router pattern)
    ├── system-design-tester/ # OpenCode skill: generate timestamped SD test papers
    ├── system-design-tutor/ # OpenCode skill: answer keys, grading, and reasoning for SD tests
    ├── tui-bubble-tea-creator/ # OpenCode skill: generate a Go Bubble Tea TUI from a spec
    ├── update-docs/       # OpenCode skill: auto-update docs from git changes
    └── yt-summarizer/     # OpenCode skill: summarize YouTube videos, export to markdown/EPUB
```

## Modules

Modules are grouped into platform layers and selected at build time by [`modules/default.nix`](modules/default.nix), so Home Manager only builds what the host can run. A universally-compatible package is added **once** to `common/packages.nix`; a Linux-only or macOS-only tool goes in the matching layer.

### Platform layers

| Layer | Imported when | Contains |
|---|---|---|
| `common/` | always | Cross-platform packages and config (see the sections below) |
| `linux/` | `pkgs.stdenv.hostPlatform.isLinux` | Linux packages, systemd services, `/mnt/hdd` mounts, Immich localtime mount |
| `linux-aarch64/` | Linux **and** `isAarch64` | Pi 5 hardware: V4L2 decoder passthrough + Immich HW transcode |
| `darwin/` | `pkgs.stdenv.hostPlatform.isDarwin` | macOS packages, the launchd Filebrowser agent, the `opl` LM Studio launcher, and the Roblox/Luau toolchain with Studio MCP wiring |

### core.nix

Sets the user identity and Home Manager state version. The username is resolved dynamically from the `$USER` environment variable (falling back to `ryuzaki` if unset), and the home directory prefers `$HOME` (falling back to `/Users/<user>` on macOS and `/home/<user>` on Linux), so the same flake works across NixOS, Debian, RPi OS, and macOS without editing.

```nix
currentUser = builtins.getEnv "USER";
userName = if currentUser == "" then "ryuzaki" else currentUser;
envHome = builtins.getEnv "HOME";

home.username = userName;
home.homeDirectory =
  if envHome == "" then
    (if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${userName}" else "/home/${userName}")
  else envHome;
home.stateVersion = "25.11";
programs.home-manager.enable = true;
```

### env.nix

Exports session variables:

| Variable | Value |
|---|---|
| `EDITOR` | `nixvim-editor` |
| `RTK_DISABLED` | `1` — RTK token compression is opt-in only; use the `oprtk` fish function to enable it for one session |

### fish.nix

Configures Fish as the login shell.

**Interactive shell initialisation:**
- Sources the Nix daemon profile for environment integration (existence-guarded so it works with the official multi-user install on Linux and macOS)
- Re-exports `EDITOR` for shell sessions
- Binds autosuggestion acceptance to multiple keys: **Ctrl+Space**, **Alt+Space**, **Alt+.**, and **Shift+Tab**

**Aliases:**

| Alias | Command |
|---|---|
| `nixvim` | `nix run github:Ryuzaki5100/nixvim --refresh` |
| `rebuild-home-manager` | `~/dotfiles/scripts/sync-rtk-plugin.sh && home-manager switch --impure --flake ~/dotfiles#(whoami) && exec fish` |
| `update-home-manager` | `cd ~/dotfiles && nix flake update && ./scripts/sync-rtk-plugin.sh && cd -` |
| `search` | `nix search nixpkgs` |
| `clock` | `clock-rs -c bright-black -B -b` |
| `display` | `chafa -f kitty --fit-width` |
| `edot` | `cd ~/dotfiles && nixvim` |
| `dot` | `cd ~/dotfiles` |
| `ga` | `git add .` |
| `yt` | `~/dotfiles/scripts/download-vid.sh` |
| `build-epubs` | `~/dotfiles/scripts/build-epubs.sh` |
| `crt` | `retrocrt` (CRT/VHS video styliser) |
| `sz` | `du -sh ` |
| `opt` | `nix-store --optimise` |
| `collect-garbage` | `nix-collect-garbage` |

**Functions:**

| Function | Description |
|---|---|
| `op` | Shorthand for `opencode`. Passes all arguments through unchanged. |
| `oprtk` | Shorthand for `opencode` with RTK token compression enabled for that session (sets `RTK_DISABLED=0`, overriding the global default of `1`). |
| `generate-ssh-key` | Prompts for an email and generates an Ed25519 SSH key (`ssh-keygen -t ed25519 -C "<email>"`) |
| `rebuild-nixos` | Rebuilds the NixOS system from `~/rpi-nixos` via `nixos-rebuild switch --flake`. Gracefully errors if not on NixOS or the flake directory is missing. |
| `update-nixos` | Updates the flake lock for `~/rpi-nixos`. Harmless on non-NixOS hosts. |

`op` and `oprtk` shadow a user completion file (`~/.config/fish/completions/op.fish` / `oprtk.fish`) over Fish's embedded `op` completion, which would otherwise invoke the real `op` binary during tab completion.

### opencode.nix

Configures [OpenCode](https://opencode.ai) — an AI coding assistant — via `programs.opencode`.

**Model:** Default model set to `opencode/deepseek-v4-flash-free`.

**MCP server configuration:**
- Servers live under `mcp.servers.<name>` (OpenCode 2 schema). The older flat `mcp.<name>` form is deprecated; `programs.opencode.validateFiles.config = true` validates the generated `opencode.json` against the schema shipped in the `opencode` package, so a drifted shape fails the build instead of silently disconnecting a server
- Defines a Gmail MCP server using `mcp-google-gmail` with paths to OAuth credentials and token. It is **enabled by default** — set `programs.opencode.settings.mcp.servers.gmail.disabled = true` to disable it
- Launches via `uv run --no-project --with "mcp-google-gmail" --with "mcp>=1.8.0,<2" mcp-google-gmail`, pinning `mcp<2` because `mcp-google-gmail` requires the `fastmcp` module that was removed in `mcp` 2.0.0
- Defines a Firecrawl MCP server (`firecrawl-mcp`, **enabled**, keyed on `~/.config/firecrawl/api-key`) — see [`firecrawl.nix`](#firecrawlnix)
- On macOS, [`roblox.nix`](#robloxnix) adds a `roblox` server that runs Roblox Studio's bundled MCP server through the `roblox-studio-mcp` wrapper

**Skill deployment:**
- Automatically discovers subdirectories under `skills/` and symlinks **every file** inside each into `~/.config/opencode/skills/<name>/`, preserving the relative layout (so a router `SKILL.md` can route to `GUIDE.md`, `references/*.md`, `templates/`, and `scripts/` from its deployed base directory)
- `.DS_Store` and other dotfiles are skipped; `scripts/*.sh` are marked executable
- Because a Flake only sees files tracked by Git, **new skill files must be `git add`ed before `home-manager switch`** (untracked files are invisible to the build)
- This makes locally-developed skills available to OpenCode without manual copying

**RTK token compression:**
- Deploys the vendored upstream plugin (`rtk.ts`) into `~/.config/opencode/plugins/`, where OpenCode auto-loads it
- The plugin rewrites shell commands through `rtk hook opencode` to cut token usage; all rewrite and permission logic lives upstream in rtk
- Disabled by default via `RTK_DISABLED=1` (see [`env.nix`](#envnix)); run `oprtk` instead of `op` to enable it for a single session
- [`scripts/sync-rtk-plugin.sh`](scripts/sync-rtk-plugin.sh) re-vendors `modules/common/rtk-opencode.ts` from the upstream tag matching the `rtk` version in the locked nixpkgs, and is run automatically by `update-home-manager` and `rebuild-home-manager`. It refuses rtk versions below `0.52.0` (the first with OpenCode 2 plugin support)

### packages.nix

Declarative cross-platform package list installed via `home.packages` from [`modules/common/packages.nix`](modules/common/packages.nix). Grouped by category (Linux-only extras noted in parentheses):

| Category | Packages |
|---|---|
| Editors | `neovim`, `opencode` (`code-server` on Linux) |
| Dev tools | `rtk`, `lazygit`, `tmux`, `zellij`, `fzf`, `jdk`, `maven`, `devenv`, `cmake`, `ninja`, `autoconf`, `automake`, `libtool`, `pkg-config` |
| Containers | `docker`, `docker-compose`, `jq` |
| System info | `fastfetch`, `btop`, `clock-rs`, `dripfetch`, `smartmontools` (`nitch` on Linux) |
| Media & graphics | `chafa`, `timg`, `mpv`, `ffmpeg`, `yt-dlp`, `yazi`, `pandoc`, `dysk`, `nix-search-tv` (`foliate` on Linux) |
| Networking & chat | `browsh`, `nchat`, `bitchat-cli`, `tailscale`, `reddit-tui`, `reddix`, `discordo`, `wiki-tui`, `hackernews-tui`, `youtube-tui`, `smassh`, `mangal` (`bluetuith`, `wifitui` on Linux) |
| Obsidian TUIs | `basalt`, `obsitui`, `glow`, `nixvim-editor` |
| Diagram generation | `archify` (also exports `ARCHIFY_ROOT` for the `content-to-diagram` skill) |
| Documents | TeX Live (`scheme-basic` combined with `enumitem`, `titlesec`, `geometry`, `hyperref`, `ec`, `cm-super`) for resume builds, plus `poppler-utils` (`pdfinfo`, `pdftotext`) for PDF validation |
| Fun | `cmatrix`, `posting`, `asciiquarium` |

Platform-specific packages live in [`modules/linux/packages.nix`](modules/linux/packages.nix) (`code-server`, `nitch`, `bluetuith`, `wifitui`, `exfatprogs`, `foliate`, plus `vial` on `x86_64-linux`) and [`modules/darwin/packages.nix`](modules/darwin/packages.nix). macOS uses `fastfetch` in place of `nitch`, and native Bluetooth/Wi-Fi/exFAT in place of the Linux TUIs. `vial` is gated to `x86_64-linux` because nixpkgs does not build it for `aarch64-linux`. macOS additionally installs Qt 6 base/charts, FFmpeg development outputs, `glslang`, `spirv-tools`, and `zstd` (plus its dev output) for building Eden, and the .NET 10 SDK (with `DOTNET_ROOT`) for switch2mac's shader translator.

> **Note:** `localsend` is commented out because its Flutter dependency (`aapt`) doesn't support `aarch64-linux`. It will be re-enabled once upstream support lands.

> **Note:** `pandoc` doubles as the EPUB converter for the [`yt-summarizer`](#yt-summarizer) skill.

> **Note:** `wifitui` requires your user to be in the `netdev` group and a polkit rule allowing NetworkManager actions. On Debian systems, run:
>
> ```bash
> sudo usermod -aG netdev $USER
> echo 'polkit.addRule(function(a, s) {
>   if (a.id.indexOf("org.freedesktop.NetworkManager.") == 0 && s.active && s.isInGroup("netdev"))
>     return polkit.Result.YES;
> })' | sudo tee /etc/polkit-1/rules.d/10-networkmanager-wifi.rules
> sudo systemctl restart polkit
> ```
>
> Then log out and back in for the group change to take effect.

### gmail-mcp.nix

Installs packages needed for Gmail MCP authentication — `uv` and `gmail-mcp-auth`.

The MCP server configuration itself was moved to [`opencode.nix`](#opencodenix).

**What it does:**
- Installs `uv` (Python package manager)
- Installs `gmail-mcp-auth` — a system-level wrapper around `gmail-mcp-auth.py` that bundles `google-auth-oauthlib`

**Reproducibility:**
| Aspect | Reproducible? | How |
|--------|-------------|-----|
| HM module (`gmail-mcp.nix`) | ✅ In git | Declared in Nix |
| `uv` installation | ✅ Via HM | `home.packages = [ pkgs.uv ]` |
| `gmail-mcp-auth` | ✅ Via HM | Built from `pkgs/gmail-mcp-auth.nix` |

**On a new machine:**
```bash
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles
home-manager switch --impure --flake ~/dotfiles#$(whoami)
# Copy credentials.json to ~/.config/gmail-mcp/credentials.json
bash ~/dotfiles/scripts/setup-gmail-mcp.sh
```

### firecrawl.nix

Configures the [Firecrawl](https://firecrawl.dev) MCP server — web search, scraping, and site crawling for OpenCode — via `programs.opencode.settings.mcp.firecrawl`.

**What it does:**
- Installs `nodejs` (needed to run `npx`)
- Defines a `firecrawl` MCP server (**enabled by default**) running `npx -y firecrawl-mcp@3.23.8`
- Supplies the API key from `~/.config/firecrawl/api-key` via OpenCode's `{file:...}` secret syntax

**Setup on a new machine:**
```bash
home-manager switch --impure --flake ~/dotfiles#$(whoami)   # installs nodejs + MCP config
bash ~/dotfiles/scripts/setup-firecrawl.sh       # saves the API key
```

### immich.nix

Deploys [Immich](https://immich.app) — a self-hosted photo and video management server — as a Docker Compose stack. The compose file and `.env` are generated on **every** platform from [`modules/common/immich.nix`](modules/common/immich.nix); Linux layers flip on host-specific bits.

**What it writes:**
- `~/.config/immich/docker-compose.yml` — Immich server, machine learning, Redis (Valkey), and PostgreSQL services, exposed on port `2283`. Both the server and machine-learning services have Docker healthchecks enabled. `devices:` and the `/etc/localtime` bind-mount are emitted only when enabled by a platform layer.
- `~/.config/immich/.env` — storage locations, `TZ=Asia/Kolkata`, pinned `IMMICH_VERSION=v3`, and `IMMICH_HW_ACCEL_ENABLED` (true only where a decoder is passed through)
- Creates `~/immich/postgres` for database data and scaffolds the library subdirectories (`profile`, `thumbs`, `upload`, `library`, `backups`, `encoded-video`) inside `~/immich/library`

**Options** (`services.immich.*`):

| Option | Default | Set by |
|---|---|---|
| `enable` | `true` | — |
| `mountLocaltime` | `false` | `modules/linux/immich.nix` (`true`) |
| `hardwareAcceleration` | `false` | `modules/linux-aarch64/immich-hwaccel.nix` (`true`) |
| `devices` | `[ ]` | `modules/linux-aarch64/immich-hwaccel.nix` (`/dev/video19`) |

**Storage layout:**
- `~/immich/library` — photo/video uploads; on Linux intended to be a symlink to `/mnt/hdd/immich/library` (see `make immich-link-library`)
- `~/immich/postgres` — database data (must stay on local disk, not a network mount)

**Platform notes:**
- **aarch64-linux (Pi 5):** `/dev/video19` is passed through and `IMMICH_HW_ACCEL_ENABLED=true` for V4L2 HEVC transcoding.
- **aarch64-darwin:** runs on Docker Desktop; no device passthrough or hardware acceleration.
- All services use `restart: "no"` — containers are started/stopped explicitly via the Makefile targets, not auto-restarted on boot.

### filebrowser.nix

Runs [Filebrowser](https://filebrowser.org) — a web-based file manager — as a **user service** so files (e.g. `~/Movies`) can be uploaded/downloaded from another device via a browser.

**Layering:**
- [`modules/common/filebrowser.nix`](modules/common/filebrowser.nix) defines the options, installs the package, and builds the shared DB-bootstrap script.
- [`modules/linux/filebrowser.nix`](modules/linux/filebrowser.nix) declares the `systemd.user.services.filebrowser` unit (`Restart=on-failure`, bootstrap as `ExecStartPre`).
- [`modules/darwin/filebrowser.nix`](modules/darwin/filebrowser.nix) declares a `launchd.agents.filebrowser` agent (`RunAtLoad`, `KeepAlive = { SuccessfulExit = false; }`) that runs the bootstrap before `exec`ing filebrowser.

It serves `--root` (default `~`) on `--address 0.0.0.0:8080`.

**Options** (`services.filebrowser.*`, defined in [`modules/common/filebrowser.nix`](modules/common/filebrowser.nix)):

| Option | Default | Description |
|---|---|---|
| `enable` | `true` | Turn the module on |
| `root` | `~` | Directory Filebrowser serves |
| `port` | `8080` | Listen port |
| `address` | `0.0.0.0` | Listen address |
| `username` | `admin` | Initial admin username |
| `password` | `changeme` (example) | Initial admin password (plaintext; Filebrowser hashes it). Override with your own value — the real password is never stored in this repo. |
| `tusChunkSize` | `2147483648` (2 GiB) | TUS chunk size; workaround for [filebrowser#5987](https://github.com/filebrowser/filebrowser/issues/5987) — Safari freezes after the first chunk with the default 10 MiB, so it's sized above any expected upload |

> **Note:** The database is only re-initialized if it doesn't exist. To apply a change to `tusChunkSize` or the initial `password` on an existing install, delete `~/.config/filebrowser/filebrowser.db` and re-run `home-manager switch` (or use `scripts/init-filebrowser.sh`, which sets both every run).

### obsidian.nix

Sets up the Obsidian vault ecosystem for terminal-based note-taking.

- **Vault discovery** — writes `~/.config/obsidian/obsidian.json` declaring a vault named `personal` at `~/notes`
- **Directory scaffolding** — ensures `~/notes/.keep` exists so the vault path is present on disk
- **Basalt TUI** — writes `~/.config/basalt/config.toml` with:
  - `vim_mode = true`
  - `experimental_editor = true`
  - Custom keybindings:
    - **Ctrl+E** — open current note in Nixvim
    - **Ctrl+Alt+E** — spawn Nixvim in a new terminal window for the current note

### ghostty.nix

Declarative configuration for the [Ghostty](https://ghostty.org) terminal (macOS layer), plus a live theme picker that mirrors the [`glow.nix`](#glownix) override pattern.

- **Config location** — Home Manager writes `~/.config/ghostty/config` (an XDG path Ghostty reads on macOS).
- **Package** — `pkgs.ghostty-bin` (the prebuilt 1.3.1 `.app` from nixpkgs) is installed, so no Homebrew cask is needed. Home Manager copies the bundle into `~/Applications/Home Manager Apps/Ghostty.app` and puts the `ghostty` CLI wrapper on `PATH`. Fish shell integration is enabled (Ghostty exports `$GHOSTTY_RESOURCES_DIR` to spawned shells).
- **Font** — `nerd-fonts.jetbrains-mono` is installed (linked into `~/Library/Fonts/HomeManager/truetype/NerdFonts/JetBrainsMono`) and set as `font-family = "JetBrainsMono Nerd Font"` at `font-size = 20` with `font-thicken = true` for glyph/icon coverage.
- **Pretty defaults** — transparency + blur (`background-opacity = 0.7`, `background-opacity-cells = true`, `background-blur = true`), Display P3 colors, window padding, block cursor, `copy-on-select = clipboard`, `mouse-hide-while-typing`, and `macos-option-as-alt`. `background-opacity-cells` extends the window opacity to app-painted cells, so TUIs that repaint the background (opencode, Neovim, tmux) are see-through for every theme instead of rendering opaque.
- **Split navigation** — `alt+shift+h/j/k/l` move between splits in Vim directions; split creation stays on the Ghostty defaults (`cmd+d`, `cmd+shift+d`).
- **Default theme** — `Catppuccin Mocha`.
- **Runtime theme override** — the config includes `config-file = ?~/.local/state/ghostty/theme.ghostty`. Because Ghostty loads includes *after* the main file, the picker can change the active theme without editing the managed config, and the override survives `home-manager switch`.
- **`ghostty-set-theme`** — a fish function that runs an `fzf` picker over `ghostty +list-themes --plain` (all 460+ built-ins plus any user themes in `~/.config/ghostty/themes`), with a live truecolor swatch preview rendered by the private `_ghostty-theme-preview` helper. Pass a name to set it directly, or `--reset` to fall back to the default.

```bash
ghostty-set-theme                     # fzf picker with live color preview
ghostty-set-theme "TokyoNight Night"  # set directly
ghostty-set-theme --reset             # back to Catppuccin Mocha
```

### opencode-lmstudio.nix

macOS-only launcher (`opl`) that opens [opencode](#opencodenix) against [LM Studio](https://lmstudio.ai)'s headless local server, exposing **only** models that are present on disk and can actually run on this machine.

- **Deployment** — lives in the `darwin/` layer, so the `opl` command, the pinned Python interpreter, and [`opl.py`](modules/darwin/opl.py) never exist on Linux hosts. Deployed with `pkgs.writers.writePython3Bin` (stdlib only) and added to `home.packages`.
- **Server** — starts `lms server start` on demand (headless, default port `1234`) and reuses an already-running server.
- **Inventory** — reads `lms ls --json --llm`, keeping LLMs with non-zero size. A model is dropped when `lms load <key> --estimate-only` exits non-zero (missing/incomplete files).
- **Context sizing** — picks the largest power-of-two context (`8192` … model max) that fits the RAM budget: `0.85 × physical RAM − 2 GiB − already-loaded models`. GGUF models use LM Studio's own estimate at each candidate; MLX/flat estimates derive KV-cache bytes from the model's `config.json` (`text_config`).
- **opencode config** — injected through `OPENCODE_CONFIG_CONTENT` (no edits to the managed `opencode.json`): `enabled_providers = ["lmstudio"]`, `model`/`small_model` set to the first loadable model, and a `lmstudio` provider with a whitelist of the selected models and their per-model context limits.
- **Lifecycle** — opencode JIT-loads a model on the first request. The launcher snapshots loaded instances before launch and, when opencode exits (including `SIGINT`/`SIGTERM`/`SIGHUP`), unloads only the instances it created — models already loaded by Bionic are left alone.

```bash
opl                    # start server (if needed) and open opencode
opl -m lmstudio/qwen/qwen3.8-27b
opl --print-config     # show the generated config + chosen contexts
opl --verbose          # explain model/context selection
opl --no-server        # do not auto-start LM Studio
```

Tunables: `--ram-fraction` (default `0.85`), `--reserve-gib` (default `2`), `--max-context` (default `262144`).

### roblox.nix

macOS-only Roblox/Luau development layer. Roblox Studio itself is deliberately **not** packaged: it installs and updates through Roblox's own installer, and its MCP server ships inside the `.app`. Everything on our side of that boundary is pinned by nixpkgs.

- **Toolchain** — `rojo` (filesystem ↔ DataModel), `selene` (lint), `stylua` (format), `luau-lsp`, `luau`, and `lune`. `wally` is intentionally absent because nixpkgs marks it `badPlatforms` on `aarch64-darwin`; pin its prebuilt release in a project's `devenv.nix` if a game ever needs packages.
- **Studio MCP** — registers `mcp.servers.roblox` so OpenCode can read the game tree, edit scripts, run Luau, and drive playtests against an open Studio session. Tool enumeration is slower than a typical MCP server, hence explicit `timeout` values (`startup 60s`, `catalog 120s`, `execution 300s`).
- **`roblox-studio-mcp`** — a wrapper installed by nix that locates Studio's bundled `StudioMCP` on macOS (or `%LOCALAPPDATA%\Roblox\mcp.bat` on Windows) and execs it, failing loudly when Studio is missing. Projects commit `.opencode/opencode.json` and `.mcp.json` that reference this name, so no absolute `.app` path ever lands in a repository.
- **`luau-lsp-roblox`** — the language server OpenCode drives for `.luau`/`.lua`. It passes `--sourcemap=sourcemap.json` and `--definitions=globalTypes.d.luau` only when those files exist, because handing luau-lsp a missing path makes it fail at startup. Registered through `programs.opencode.settings.lsp`.
- **Enabling it** — once in Studio: Assistant → `…` → Manage MCP Servers → *Enable Studio as MCP server*. The green indicator means a client connected. Studio scans `~/Documents/Roblox/Plugins` only at startup, so refresh the Rojo plugin by quitting Studio fully before reopening.

### glow.nix

Declarative theming for the [`glow`](https://github.com/charmbracelet/glow) terminal markdown renderer. Every `glow/themes/*.json` (a glamour v2 `ansi.StyleConfig`) is deployed to `~/.config/glow/themes/<name>.json`, so the theme set is defined entirely by files in the repo.

- **Default theme** — `~/.config/glow/glow.yml` sets `style` to the `retro-orange` theme, derived from the Nixvim `retro-orange` colorscheme palette.
- **Runtime override** — `GLOW_CONFIG_HOME` points at `~/.local/state/glow`, which glow reads *before* `~/.config/glow`, so the picker can change the active theme without editing the managed config.
- **`glow-set-theme`** — a fish function that shows an `fzf` picker over `~/.config/glow/themes.list` (regenerated at rebuild, so newly added themes appear automatically). Pass a name to set it directly, or `--reset` to return to the default.

```bash
glow-set-theme            # fzf picker
glow-set-theme gruvbox    # set directly
glow-set-theme --reset    # back to retro-orange
```

Bundled themes: `retro-orange`, `gruvbox`, `nord`, `tokyo-night`, `catppuccin-mocha`, `dracula`, `blood-red`.

### epub.nix

Declares the tooling used by [`scripts/build-epubs.sh`](scripts/build-epubs.sh) to turn the `~/interview-prep` markdown tree into EPUB books. Everything is pulled from the Home Manager profile — nothing is installed or downloaded at build time:

| Package | Purpose |
|---|---|
| `epubcheck` | EPUB 3 validation; each built book is checked and the script fails if any is invalid |
| `dejavu_fonts` | Provides `DejaVu Sans Mono`, embedded and used for code blocks and ASCII/box-drawing diagrams |
| `fontconfig` | Provides `fc-match`, used by `build-epubs.sh` to locate the font on both Linux and macOS |
| `python3` | Runs the [`epub-preprocess.py`](scripts/epub-preprocess.py) sanitizer |

`pandoc` (the actual converter) already lives in [`packages.nix`](#packagesnix).

### retrocrt.nix

Installs [`retrocrt`](scripts/retrocrt.py) — a video styliser that wraps a clip in a thick curved CRT bezel, gently degrades the picture, and stamps it with a camcorder-style date, wall clock, and video timecode. Anything ffmpeg can read is a valid input (mp4, mkv, mov, webm, ts, …).

`pkgs/retrocrt.nix` pins everything the script needs so it behaves the same on macOS and Linux:

| Component | Why it is pinned |
|---|---|
| `ffmpeg` | All pixel work: scaling, bloom, scanlines, grain, displacement wobble, glitch, lens curvature, vignette, drawtext, encode |
| `python3Packages.pillow` | Renders and caches the bezel, scanline, and rolling-band assets |
| `dejavu_fonts` (`DejaVuSansMono-Bold`) | Timestamp / timecode font, exported as `RETROCRT_FONT` |

Assets are cached in `${XDG_CACHE_HOME:-~/.cache}/retrocrt/` and regenerated only when their parameters change.

#### Quick start

```bash
crt clip.mp4                            # classic, parallel (default), -> clip-retro.mp4
crt clip.mp4 -o out.mp4 --preset vhs    # heavy VHS look
crt clip.mp4 --preset subtle            # barely-there retro
crt clip.mp4 --jobs 1                   # single process, old behaviour
crt clip.mp4 --preview 20               # first 20s only -> clip-preview.mp4
crt clip.mp4 -o out.mp4 --fast          # VideoToolbox (macOS, lower quality)
```

Quote filenames that contain spaces, `:` or `｜`:

```bash
crt "Best Bits of Season 4： Volume 1 ｜ Rick and Morty ｜ adult swim.mp4"
```

#### Presets

| Preset | Pixelation | Scanlines | Grain | Bloom | Chroma bleed | Glitch | Timestamp |
|---|---|---|---|---|---|---|---|
| `subtle` | mild | faint | light | soft | 1 px | rare | off |
| `classic` | visible | strong | medium | medium | 2 px | moderate | date + clock + timecode |
| `vhs` | heavy | strong | heavy | strong | 4 px | frequent + rolling band | date + clock + timecode + blinking `REC` |

`--intensity N` scales every effect at once (`0` = almost clean, `1` = preset default, `2` = doubled). Individual effects can be turned off with `--no-scanlines`, `--no-bezel`, or `--no-timestamp`.

#### Bezel

The screen opening is a rounded rectangle by default (gentle corners, straight edges) drawn over slightly over-scanned video, giving a rectangular CRT housing rather than an oval tube. Set `--bezel-radius 0` to use a superellipse controlled by `--bezel-curve` instead.

| Flag | Default | What it does |
|---|---|---|
| `--bezel-style plastic\|wood\|metal` | `plastic` | Body material and default colour |
| `--bezel-thickness F` | `0.045` | Frame thickness as a fraction of output height (`0.02` thin, `0.10` chunky) |
| `--bezel-radius F` | `0.05` | Corner radius as a fraction of the window. `0.03` subtle, `0.10` soft TV, `0` switches to the superellipse |
| `--bezel-curve N` | `6.0` | Superellipse exponent when `--bezel-radius 0`: `2` = ellipse, `4` = rounded TV, `8+` = squarer |
| `--bezel-color '#rrggbb'` | style-based | Override the plastic/wood/metal colour |
| `--no-highlight` | off | Remove the inner rim highlight |
| `--height PX` | source + bezel | Fixed output canvas height (e.g. `1080`); width follows the source aspect |
| `--no-bezel` | off | Keep all effects but skip the frame and canvas padding |

#### Timestamp and timecode

`classic` and `vhs` draw three things in the bundled mono font:

- **Date** — top-left, e.g. `JUN 01 1994` (`--stamp-date`).
- **Wall clock** — top-left, ticks from `--stamp-start` (default `1994-06-01 23:58:00`).
- **Video timecode** — bottom-right `HH:MM:SS`, always starts at `00:00:00` and follows the clip's own PTS.

`vhs` adds a blinking red `● REC` next to the date and a 1 px RGB ghost. Use `--no-timestamp` to hide all of it, or `--stamp-date 'DEC 25 1987'` / `--stamp-start '1987-12-25 18:00:00'` for a different era.

#### File size

Grain, scanlines and wobble are high-frequency noise, so x264 has to spend far more bits on them than on the clean source. At the default CRF 22 a grainy 1080p clip is typically **2–3× the source size**, and CRF 18 can be 4×. The canvas is also ~15% larger than the source frame by default.

Levers, in order of impact:

| Option | Effect |
|---|---|
| `--maxrate 1400k` | Caps the video bitrate; usually lands near the source size (~10–20% bigger). Best single knob for size |
| `--crf 24` / `--crf 26` | Lower quality, smaller file; grain hides most of it |
| `--height 1080` | Removes the extra canvas pixels (~20–25% smaller) |
| `--intensity 0.7` or `--preset subtle` | Less grain/scanlines → much better compression |

Example roughly matching a 1.4 Mbit/s source:

```bash
crt episode.mp4 --maxrate 1400k
```

#### Audio

Audio is transcoded to **AAC 192 kbit/s** by default so the result plays everywhere, including QuickTime and Apple Books. This matters for sources whose audio is Opus or Vorbis (common in MP4/WebM), which ffmpeg can mux but Apple players cannot decode. Use `--copy-audio` to keep the original stream untouched, or `--audio-age` to muffle it (`highpass` + `lowpass`) and add a short echo, which pairs well with `vhs`.

#### Output, batch mode and progress

- Single input without `-o` → `<name>-retro.mp4` next to the source (`<name>-preview.mp4` with `--preview`).
- Single input with `-o file.mp4` → exact path.
- Multiple inputs with `-o dir/` → `dir/<name>-retro.mp4` for each; without `-o` they land beside each source.
- Encoding writes H.264 `yuv420p` with `+faststart` (CRF 22, AAC audio). `--crf` changes quality; `--maxrate 1400k` caps the bitrate if file size matters. `--fast` switches to macOS VideoToolbox.
- The encode goes to a sibling `<name>.part.mp4` first and is renamed only after ffmpeg finalizes the container. If the run is interrupted (Ctrl+C, SIGTERM, closed terminal, crash), the partial file is deleted, so you never get a `moov atom not found` MP4 under the real name.
- An existing output is never replaced unless you pass `--overwrite`.
- Progress is shown when stderr is a terminal: a live bar per segment plus a total line, or one bar for `--jobs 1`. Hidden automatically when piped; `--no-progress` disables it.

#### Parallel encoding (`--jobs`)

`--jobs` (default `auto`) splits a single video into frame-aligned segments, encodes them concurrently, then concatenates the result and muxes one audio pass:

| Value | Behaviour |
|---|---|
| `auto` (default) | `round(cores / 3)`, clamped to `2..6` — 4 jobs on a 12-thread Mac; 2 on an 8-thread one |
| `N` | exactly N segments / concurrent files |
| `1` | old single-process path (no splitting) |

With several inputs, `--jobs` instead runs up to N files concurrently (each with its own ffmpeg process).

Details:

- Effects are time-aware across joins: each segment's PTS is offset before filtering and reset afterwards, so glitch/wobble/rolling-band timing, the wall clock, and the video timecode stay continuous.
- Segments are cut by frame count, not approximate seconds, so joins are clean (±1 frame in practice, invisible under the CRT treatment).
- Audio is encoded once for the whole clip and muxed at the end, avoiding AAC gaps at boundaries.
- Work happens in `.retrocrt-<random>/` beside the output; it is removed on success, failure, or interrupt. Temp disk usage is about one extra copy of the output.
- Each segment gets its own live progress bar (percent, elapsed/total, per-segment speed); a total line appears when the run completes.

**Measured** on a 12-thread Apple Silicon Mac, 1080p `vhs`: ~65s single-process → ~34s with 4 jobs for a 60s clip (~1.9×). The single process already uses ~6 cores, so 4–6 jobs is the practical ceiling without reducing quality or using `--fast`. Each segment gets `cores / jobs` encoder and filter threads, so all bars advance together instead of one racing ahead. The environment variables `RETROCRT_SEG_THREADS` and `RETROCRT_SEG_FILTER_THREADS` override those values for tuning.

The first few seconds show all bars at 0% while x264 warms up; after that they advance in lockstep.

#### Preview mode (`--preview`)

`--preview SECONDS` encodes only the first N seconds and writes `<name>-preview.mp4` (unless `-o` is given). Timestamps still start at zero, so a preview matches the final output exactly. Combine with `--jobs` as usual.

```text
  [#################-------------]  57.3%  11:32/20:08    1.42x
```

#### Recipes

```bash
# Clean-ish retro for an anime episode, 1080p
crt episode.mkv -o episode-retro.mp4 --preset classic --height 1080

# Fast look-dev: 20s preview in ~10s instead of rendering the whole episode
crt episode.mkv --preview 20 --preset vhs

# Tune the parallel split explicitly
crt episode.mkv --jobs 4

# Full VHS pastiche with reproducible glitches and degraded audio
crt holiday.mp4 --preset vhs --audio-age --seed 1994

# Old camcorder date, thin metal frame, no scanlines
crt wedding.mp4 --stamp-date 'AUG 14 1993' --bezel-style metal \
    --bezel-thickness 0.04 --no-scanlines

# Batch a season folder, keeping each file beside its source
crt Season\ 04/*.mkv --preset subtle --seed 7

# Preview the filtergraph without encoding
crt clip.mp4 --dump-filter
```

#### Performance

The wobble/displacement, bloom, grain and lens stages run per pixel and dominate CPU time; a 1080p `vhs` encode needs roughly 6 s of CPU per second of video. `--jobs auto` already turns that into ~2× wall-clock speedup on a 12-thread machine. For long episodes:

1. `--jobs 4` (or `auto`) is the measured sweet spot; more jobs oversubscribe and get slower.
2. `--fast` (VideoToolbox) offloads x264 and is the next biggest win, at some quality cost.
3. `--preset subtle --intensity 0.6` skips the heaviest grain/bloom.
4. `--height 720` roughly halves the pixel work.
5. Bezel and scanline PNGs are cached, so repeat runs start immediately.
6. `--preview 20` checks a preset in seconds.

#### Troubleshooting

| Symptom | Fix |
|---|---|
| Looks too clean | Raise `--intensity` (e.g. `1.4`) or move to a stronger preset |
| Glitches too frequent/rare | `--intensity` scales them; `--seed` only changes the pattern, not the rate |
| Too slow on a long clip | `--jobs auto` is on by default; try `--fast`, `--height 720`, or lower `--intensity` |
| Parallel run slower than expected | Try `--jobs 4`; 8+ jobs oversubscribe a 12-thread machine. Very short clips also pay process-startup overhead, so `--jobs 1` can win. |
| Timestamp missing | `--preset subtle` has none; use `classic`/`vhs` or check `--font` |
| Text clipped by the frame | Use the default bezel or reduce `--bezel-thickness`; very thick frames shrink the safe area |
| Bezel looks too oval | Default is a rounded rectangle (`--bezel-radius 0.05`); use a smaller radius (e.g. `0.03`) or `--bezel-radius 0 --bezel-curve 8` for squarer corners |
| Output is much larger than the source | Grain/scanlines dominate bitrate. Use `--maxrate 1400k`, `--crf 24`, `--height 1080`, or a lighter `--intensity` |
| Output is bigger than needed | Pass `--height 1080` (or lower); the canvas otherwise matches source height |
| QuickTime/Finder says the MP4 “could not be opened” | Update and re-run; older builds could leave a truncated file after an interrupt. The current version writes atomically and transcodes audio to AAC. Use `--overwrite` to replace the old broken file. |
| `moov atom not found` when probing | The file was never finalized; delete it and re-run (the temp-file write prevents this now) |
| Audio silent/unplayable in Apple apps | The source is likely Opus/Vorbis; the default AAC transcode fixes it (`--copy-audio` opts out) |
| Warnings about colourspace conversion | Harmless; the encode log is now quiet by default (`-loglevel error`) |

## Skills

OpenCode skills are stored in `skills/` and auto-deployed to `~/.config/opencode/skills/<name>/` by the [`opencode.nix`](#opencodenix) module — every file in a skill directory is symlinked recursively, so a lean router `SKILL.md` can route to on-demand companions (`GUIDE.md`, `references/*.md`, `templates/`, `scripts/`) without bloating the always-loaded context.

### skill-creator

Interactive wizard for creating new OpenCode skills. It gathers the name, description, and behavior, picks a file topology (`single`, `router+guide`, or `router+references`), then writes a context-efficient `SKILL.md` router with a **Files & routing** table plus any on-demand `GUIDE.md`/`references/`/`scripts/`/`templates/` companions, and validates the result. The full pattern (templates, budget rules, worked example) lives in the skill's `GUIDE.md`.

### Pebble suite

`pebble-app` is the orchestrator for a 10-skill suite that builds Pebble watchfaces and watchapps end to end: classify the request, scaffold metadata, design a pixel-accurate layout, implement in C or Alloy, add PebbleKit JS/Clay phone code, build and verify on the emery emulator, then generate release assets. The Pebble SDK core, ARM/Moddable toolchain, QEMU, Python and Node environments are all Nix-packaged; `pebble sdk install` is not used. Supporting skills are `pebble-core`, `pebble-sdk-setup`, `pebble-project-scaffold`, `pebble-ui-design`, `pebble-c-dev`, `pebble-alloy-dev`, `pebble-phone`, `pebble-build-test`, and `pebble-release`.

### content-to-diagram

Turns pasted text, a Markdown file, notes, a README, an article, a transcript, a PDF, or any other readable document into a validated, interactive [Archify](https://github.com/tt-a1i/archify) HTML diagram. It always asks which of Archify's ten diagram types to use, then reads the relevant schema and example from the installed package. The clean pipeline keeps all intermediates in a disposable `$TMPDIR` workspace, runs `validate` → `render` → `check`, and moves only the finished `<slug>.html` into the requested directory — no candidate JSON, `.archify/` folder, delivery receipt, or browser-check sidecar is left beside it.

### manga-merger

Merges a directory of per-chapter/volume image folders into one Apple Books-compatible fixed-layout EPUB in the current working directory. It discovers pages with natural numeric ordering (`Ch.0001.1` < `Ch.0001.2` < `Ch.0002`; `2.jpg` < `10.jpg`), builds chapters from folder names, letterboxes every page onto one shared canvas so Apple Books does not clip them, and validates the ZIP/mimetype/spine/image count before reporting. The bundled `scripts/build_epub.py` is Python 3 stdlib only — no Calibre, Pillow, or ImageMagick needed.

### tui-bubble-tea-creator

Builds a complete Go TUI (Bubble Tea + Bubbles + Lip Gloss) from a specification — supplied as a path to a markdown spec or inline in the prompt. The router `SKILL.md` inlines the non-negotiable Elm-architecture rules and drives a staged, stop-and-verify build (skeleton + devenv/flake/justfile → navigation → data → features → polish), while the full playbook (vim keymap, pending-key buffer, layout/resize, testing, packaging, CI) is read on demand from its `GUIDE.md`.

### ai-era-mock-interview

Runs an AI-era mock interview inside a fresh working directory: the agent plays **both interviewer and Copilot**, scaffolding a buggy Java/Maven `codebase/` from a curated or generated scenario plus a symptom-driven `TICKET.md`. Candidate prompts are sent with `>ai:` (routed to the Copilot and logged to `prompt-log.md`), nudges with `>hint:` (each costs points), and plain messages go to the interviewer. It interleaves system-design and theory follow-ups drawn from `~/system-design/`, then grades prompt quality (5 dimensions), the resulting code diff, and the design discussion into `evaluation.md`, appending one line to `~/interview-sim/history.jsonl`.

Curated scenarios live under `skills/ai-era-mock-interview/scenarios/` (N+1 query, IDOR, deadlock on transfer, fixed-window rate limiter) with hidden `solution.md`/`rubric.md`; the bug-class taxonomy and difficulty mapping are in `taxonomy.md`. Requires `jdk` + `maven` (see [packages.nix](#packagesnix)); `scripts/run-tests.sh` falls back to a `javac`/`java` harness when Maven is unavailable. A candidate-facing walkthrough ships as the skill's `GUIDE.md`.

### glow-theme-creator

Turns a described vibe (e.g. "warm retro CRT amber") into a new glamour v2 theme JSON in `glow/themes/` — deriving a palette and matching code-block syntax colors, validating with `jq`, previewing with `glow -s`, and instructing you to rebuild so `glow-set-theme` lists it.

### daily-prep-questions

Runs `skills/daily-prep-questions/scripts/generate-daily.py` to emit 8 deterministic, no-repeat interview-prep questions per day — 3 LeetCode, 2 system design, 1 behavioral, 1 SQL, and 1 LLD — drawn from curated JSON banks in `data/`. Progress is tracked in `progress.json` (pointer-based, so a bank only repeats after a full cycle); `--reset` restarts the cycle and `--show` replays a saved day. The skill also prompts the solve/tracking workflow (LC tracker CSV, SD sketches, STAR answers, SQL `EXPLAIN ANALYZE`, LLD class diagrams).

### hld-problems-generator

Generates system-design practice problems by synthesizing the `~/system-design` reference library. After asking for a problem source (existing / novel / hybrid) and difficulty (junior → senior-architect), it creates a timestamped `practice-problem-<ts>/` folder in the CWD with an AI-interviewer-ready `question.md`, an architect-level `answer.md` (estimation, component deep dives, tradeoff and failure tables, scaling evolution), and EPUB versions of both via `pandoc`.

### system-design-tester

Generates a system-design test paper from selected `~/system-design` topics and writes timestamp-matched `questions-<timestamp>.md` and `.epub` files at the repository root. It supports topic-drill and cumulative modes, configurable difficulty/count/type mix/time limit, and records studied topics and scores in a repo-root `.sd-tester/ledger.json`. Questions embed a `SOURCE-MAP` linking each item back to its source heading; answers are produced separately by `system-design-tutor`.

### system-design-tutor

Companion to `system-design-tester`. Reads a `questions-<timestamp>.md` paper (matched by the shared timestamp token), writes `answers-<timestamp>.md` and `.epub` with model answers, key points, rubrics, common mistakes, and source citations, grades a submitted attempt against the rubric, and explains the reasoning behind any question from the underlying source markdown.

### roblox-git-bridge

Attaches a Roblox Studio game to a GitHub repository and keeps four surfaces in agreement: `src/` (scripts), a tracked local `.rbxlx` (geometry), the live Studio session (disposable runtime), and `origin/main` (history). The router `SKILL.md` inlines the non-negotiables — files are the source of truth for scripts, the local place for geometry, cautious syncback by default, and a hard halt when both sides diverged. `GUIDE.md` holds the ordered playbook (preflight → attach the remote → map with Rojo → pin the toolchain in `devenv.nix` → build and open the local place → CI), and five references cover repository attachment, Rojo mapping, the Studio sync handshake and divergence table, Actions/Open Cloud publishing, and the gotchas log.

`scripts/bootstrap.sh` scaffolds a repository idempotently (`--dry-run` prints the plan, existing files are never overwritten) from `templates/` (`roblox.json`, `default.project.json`, `devenv.nix`, `ci.yml`, `AGENTS.md`), and `scripts/repo/` carries the working helpers (`studio-open`, `studio-mcp`, `status`, `sync`, `preflight`, `publish`). The gotchas reference is the part worth reading first: it records ten failures — Studio only scanning plugins at startup, devenv 2.x's inert `enterTest`, the port clash, `open -a` not loading a place, Rojo silently overwriting Studio edits, `save_place` writing to disk only for local places, local places having no `placeId`, `wally` on Apple Silicon, Studio's own console noise, and flakes ignoring untracked files — each with the evidence that identifies it.

### update-docs

Analyzes git changes (working tree diff + recent commits) to find and update stale documentation. Operates conservatively — only touching sections affected by real changes, never rewriting unrelated content.

### yt-summarizer

Generates a well-structured summary of a YouTube video from its transcript (fetched via `youtube-transcript-api`, with a fallback to page metadata when captions are unavailable).

After producing the summary, the skill asks how you'd like it delivered:

| Output | Behavior |
|---|---|
| **Print only** | Summary is output in the chat; no file is written |
| **Markdown** | Saves the summary to `~/yt-summaries/<video-title>.md` |
| **EPUB** | Converts the summary with `pandoc` (already in `home.packages`) into an `.epub` with a table of contents — the summary's section headings become chapters, organized to mirror the video's content flow |

### batch-resume-tailor

Given a list of job posting URLs (Naukri, LinkedIn, company career pages, etc.), fetches each job description — either by the agent itself (`curl` through the `r.jina.ai` rendering proxy) or via the Firecrawl MCP server — and tailors one resume per role. Produces date-stamped `.tex` files in `~/my_resumes/<company>/` (e.g. `cisco_software_engineer_11-08-2026.tex`) and stores each fetched job description in `~/my_resumes/job_descriptions/`. Before regenerating a resume for a company+role that already has one, it summarizes the similarity and asks whether to keep or replace the existing file.

### single-resume-tailor

Given a single job description, curates a polished, ATS-optimized LaTeX resume from `~/my_resumes/knowledge_base.md` that fills exactly one page: keyword-mirrored bullets, a Professional Summary, a dedicated Skills block, document-wide unique action verbs, and an ATS-safe single-column layout. Saves it to `~/my_resumes/<company>/<company>_<role>.tex`.

### job-search-resume-tailor

The audited counterpart to `single-resume-tailor`. Given one job description, it classifies and prioritises the requirements, builds a candidate-to-JD **evidence matrix** with a fit verdict, and rewrites only what the evidence in `~/job-search/my_resumes/knowledge_base.md` can defend — internship vs full-time tenure, project vs production claims, and accurate technology coverage are preserved throughout. It then generates a single-column, ATS-safe LaTeX resume, compiles it, and validates page count, page size, and text extraction before writing `<company>/<company>_<role>.tex` plus the mirrored `pdfs/<company>/<company>_<role>.pdf`.

Companion references hold the per-domain keyword strategy, the evidence-and-validation rules, and the hard boundary against claiming production RAG, vector databases, or model training. `job-grabber` dispatches this skill for any verified role scoring 80+.

### job-grabber

A weekly job-search run that treats *verification* as the unit of value rather than pages scraped. The router `SKILL.md` carries the non-negotiable rules (never fabricate, discovery is not verification, never research the same posting twice, respect access controls, never claim a channel you did not use, report discovery and direct-access coverage separately); `GUIDE.md` holds the candidate profile, targeting tiers, experience gates, scoring rubric, and publication checklist.

Discovery runs cheapest-first: public ATS board APIs (Greenhouse, Lever, Ashby, SmartRecruiters) and official career portals, then search-engine indexing, then alert emails from `job-intel/inbox/`, then direct portal browsing, then secondary sources. Every shortlisted role is re-opened at the employer's own requisition before it enters the report. `references/portals.md` records the tested access method per portal — notably that LinkedIn's guest surface works over a plain HTTP fetch and Naukri's pages render through Firecrawl, both without logging in — and that a tool refusing a domain is not a portal being inaccessible.

State lives in `~/job-search/my_resumes/job-intel/` and is the memory: `ledger.json` (every posting ever seen, deduplicated on requisition ID then normalised URL, with a 14-day re-verification TTL), `sources.json` (per-run source coverage and rolling channel performance), `skills-gap.json` (recurring unmet requirements), plus `runs/<date>-weekly-report.md`, `fits/<company>_<role>/{jd.md,fit.md}`, and the alert inbox. `scripts/ledger.py` does the lookup/upsert/close/coverage/skills-gap bookkeeping; `scripts/compile_resume.sh` compiles a tailored `.tex` and enforces the mirrored `pdfs/` output, one-page A4 check, and intermediate cleanup.

## Custom Packages

### nixvim-editor

A lightweight `writeShellScriptBin` wrapper that delegates to the user's [Nixvim](https://github.com/Ryuzaki5100/nixvim) flake. Every invocation fetches the latest build (`--refresh`), ensuring the editor is always up to date without manual intervention.

```
nix run github:Ryuzaki5100/nixvim --refresh -- "$@"
```

Used as the system `EDITOR` and referenced by Basalt keybindings for opening notes.

### dripfetch

Installs [dripfetch](https://github.com/a-shygun/dripfetch) from the upstream `packaging/nix` flake input. The package is overridden with [`pkgs/dripfetch-kbinterrupt.patch`](pkgs/dripfetch-kbinterrupt.patch) so `Ctrl+C` exits cleanly instead of dumping a `KeyboardInterrupt` traceback from its `run()` loop. It is part of the common package set and is also exposed under `packages.<system>`.

### archify

Packages [Archify](https://github.com/tt-a1i/archify) — a zero-runtime-dependency Node CLI that renders validated, interactive HTML diagrams — from a pinned upstream GitHub source.

| Attribute | Value |
|---|---|
| Source | `github:tt-a1i/archify` at `v3.2.0` (commit `208acba8d412335185b2056fedf54b3405df43fb`) |
| Build | `fetchFromGitHub` + `makeWrapper` (no npm install; the CLI has no runtime npm dependencies) |
| Runtime | Node.js from nixpkgs |
| Bundled data | `SKILL.md`, schemas, examples, renderers, and locales under `$out/share/archify` |

The wrapper exports `ARCHIFY_ROOT` so the [`content-to-diagram`](#content-to-diagram) skill can read Archify's own authoring contract, and sets `ARCHIFY_UPDATE_CHECK_DISABLED=1` because versions are managed by Nix. The skill's clean pipeline uses `validate`, `render`, and `check` and leaves only the final HTML.

### bitchat-cli

Builds [bitchat-cli](https://github.com/dearabhin/bitchat-cli) — serverless peer-to-peer chat over a Bluetooth LE mesh, wire-compatible with the bitchat app — from the PyPI source tarball using `buildPythonApplication`. Provides both the `bitchat-cli` and `bitchat` commands.

| Attribute | Value |
|---|---|
| Source | `files.pythonhosted.org` (sdist) |
| Build | `buildPythonApplication` (`pyproject`/setuptools) |
| Runtime deps | `bleak`, `cryptography`, `prompt-toolkit` |
| License | GPL-3.0-or-later |

### gmail-mcp-auth

A `writeShellScriptBin` wrapper that bundles `gmail-mcp-auth.py` with a Python environment containing `google-auth-oauthlib`. Provides a system-level `gmail-mcp-auth` command for headless OAuth2 authorization with Gmail.

| Attribute | Value |
|---|---|
| Source | `scripts/gmail-mcp-auth.py` |
| Runtime | Python 3 with `google-auth-oauthlib` |

### obsitui

Builds [obsitui](https://github.com/atr0t0s/obsitui) — a terminal UI for browsing and editing Obsidian vaults — from source using `buildNpmPackage`. This avoids depending on a pre-built npm release and keeps the toolchain fully within Nix.

| Attribute | Value |
|---|---|
| Source | `github:atr0t0s/obsitui` (main) |
| Build | `buildNpmPackage` |
| License | MIT |

### retrocrt

Bundles [`scripts/retrocrt.py`](scripts/retrocrt.py) with a Python environment containing Pillow, plus a pinned `ffmpeg` and the `DejaVu Sans Mono` timestamp font. The script itself is std-lib Python; ffmpeg performs the actual video processing.

| Attribute | Value |
|---|---|
| Source | `scripts/retrocrt.py` |
| Runtime | Python 3 with `pillow`, pinned `ffmpeg`, `dejavu_fonts` |
| Cache | `${XDG_CACHE_HOME:-~/.cache}/retrocrt/` |
| Output | H.264 (`yuv420p`, `+faststart`), audio copied or aged with `--audio-age` |

## Quick Start

### Prerequisites

- Nix with flakes enabled (`nix-command` and `flakes` experimental features)
- Home Manager installed

> **On a truly fresh system without Nix**, run `bash ~/dotfiles/scripts/install-nix.sh` first.
> It installs the official multi-user (`--daemon`) Nix package manager on both Linux
> and macOS, then log out and back in before proceeding.

### Installation

**On an existing Home Manager setup:**

```bash
# Clone the repository
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles

# Build and activate the Home Manager configuration
home-manager switch --impure --flake ~/dotfiles#$(whoami)
```

**On a fresh system (bootstraps flakes + Home Manager + Fish login shell):**

```bash
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles
bash ~/dotfiles/scripts/init-home-manager.sh
```

> **Why `--impure`?** The flake reads the host platform and username
> (`builtins.currentSystem` / `builtins.getEnv`) so the same command targets Linux
> or macOS correctly. Under pure evaluation it falls back to `aarch64-linux`.

**Pure-mode alternative.** Each supported platform is also exposed as an explicit attribute, which needs no impure evaluation:

```bash
home-manager switch --flake ~/dotfiles#$(whoami)-aarch64-darwin
home-manager switch --flake ~/dotfiles#$(whoami)-aarch64-linux
```

> **If you see `platform mismatch`:** a bare `home-manager switch --flake .` evaluates
> purely, so `builtins.currentSystem` is unavailable and the `<user>` alias falls back to
> `aarch64-linux`. On a Darwin host that surfaces as `error: Cannot build … Reason:
> platform mismatch / Required system: 'aarch64-linux' / Current system:
> 'aarch64-darwin'`. The flake now warns with this explanation whenever the fallback is
> taken — switch to `--impure` or to an explicit `#<user>-<system>` attribute rather than
> retrying the bare command.

### Updating dependencies

```bash
cd ~/dotfiles && nix flake update && home-manager switch --impure --flake .#$(whoami)
```

Both commands are aliased as `rebuild-home-manager` and `update-home-manager` for convenience.

### macOS Support

The configuration is layered so Home Manager builds only the modules the host can run — see [Platform layers](#platform-layers). On Apple Silicon:

1. **Install Nix** (official multi-user installer):
   ```bash
   bash ~/dotfiles/scripts/install-nix.sh
   ```
2. **Apply the configuration and set Fish as the login shell:**
   ```bash
   bash ~/dotfiles/scripts/init-home-manager.sh
   ```
   Or manually:
   ```bash
   home-manager switch --impure --flake ~/dotfiles#$(whoami)
   echo "$(command -v fish)" | sudo tee -a /etc/shells
   chsh -s "$(command -v fish)"
   ```

**What works on macOS:** all `common/` modules — `neovim`, `opencode` (+ skills and MCP servers), `glow`, `obsidian`/`basalt`, `epub` tooling, `mangal`, the resume/interview skills, plus `docker` (Docker Desktop), `tailscale` (CLI; the app provides the daemon), `fastfetch`, media/dev tools, and Filebrowser via a **launchd** agent.

**Platform differences:**

| Feature | Linux | macOS |
|---|---|---|
| Filebrowser service | `systemd` user unit | `launchd` agent |
| Immich | Docker + `/etc/localtime`; Pi 5 gets `/dev/video19` + HW transcode | Docker Desktop; no device passthrough/HW accel |
| Tailscale | `tailscaled` + systemd unit (via `scripts/setup-tailscale.sh`) | Tailscale app (`brew install --cask tailscale`) |
| `nitch`, `code-server`, `foliate`, `bluetuith`, `wifitui`, `exfatprogs` | installed | not built (use `fastfetch`, native Bluetooth/Wi-Fi/exFAT) |
| HDD `/mnt/hdd`, Samba shares, drive backups, RPi USB-gadget, WayVNC | available (`make immich-*`, scripts) | **Linux-only** — scripts/targets exit with a clear message |

### Roblox Studio Setup

The macOS layer wires [Roblox Studio](https://create.roblox.com/docs/studio/mcp) into OpenCode so an agent can explore the DataModel, edit scripts, execute Luau, and run playtests. Studio is installed from Roblox, not from this flake.

1. **Install Roblox Studio** and sign in.
2. **Enable the MCP server** — Assistant → `…` → Manage MCP Servers → *Enable Studio as MCP server*. Check the green indicator once a client connects.
3. **Install the Rojo plugin** inside the game repository: `rojo plugin install`. Studio only scans plugins at startup, so quit with `Cmd+Q` and reopen.
4. **Verify** — `opencode mcp list` shows `✓ roblox`, and the agent can call `list_roblox_studios`.

A project carries its own pins and bridge scripts; the local `roblox-git-bridge` skill scaffolds them (`roblox.json`, `default.project.json`, `devenv.nix`, `scripts/*.sh`). Operational rules that are easy to get wrong:

| Rule | Why |
|---|---|
| Edit **scripts in files**, never in Studio | Rojo overwrites Studio-side script edits silently — it has no conflict detection |
| Keep the **local `.rbxlx`** canonical, the cloud place a publish target | MCP `save_place` writes to disk only for local places; a cloud place saves a cloud version git never sees |
| Launch Studio with `studio-open` (the binary), not `open -a` | `open -a RobloxStudio <file>` spawns a protocol-handler process that never loads the place ("Place is not open") |
| One Rojo server | `rojo serve` and `devenv up` both want port 34872; the second one dies |
| Match sessions by `placeId` or `file`, never by window title | A local place has no `placeId`, and two windows can share a name |

Deeper material lives with the work itself: the game repository's `docs/RUNBOOK.md` (cold start, daily loop, sync gesture, troubleshooting) and the skill's `references/gotchas.md`, which records each failure together with the evidence that identifies it.

### Gmail MCP Setup

Two paths: **automated** (recommended) or **manual** (understanding).

#### Automated (script)

```bash
# After home-manager switch --impure --flake ~/dotfiles
bash ~/dotfiles/scripts/setup-gmail-mcp.sh
```

The script will:
1. Verify `uv` and `gmail-mcp-auth` are installed
2. Create `~/.config/gmail-mcp/`
3. If `credentials.json` is missing, prompt you to set it up
4. If `token.json` is missing **or expired**, run the OAuth flow (prints URL → you authorize → paste redirect URL)
5. Verify the MCP server is connected

> **Note:** The MCP server is enabled by default. If you've disabled it, set
> `programs.opencode.settings.mcp.servers.gmail.disabled = false`
> in your flake configuration and run `home-manager switch`.

#### Manual (step-by-step)

<details>
<summary>Click to expand</summary>

##### 1. Google Cloud Console (one-time)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (top dropdown → New Project)
3. **Enable Gmail API:**
   - APIs & Services → Library → search "Gmail API" → Enable
4. **Configure OAuth consent screen:**
   - APIs & Services → OAuth consent screen
   - User Type: **External** (required for personal @gmail.com accounts)
   - App name: `gmail-mcp` (or anything)
   - Support email: your email
   - Developer contact: your email
   - Scopes: add `.../auth/gmail.modify` (or skip — the auth flow requests it)
   - Test users: add your Gmail address
   - Save (no need to publish)
5. **Create OAuth credentials:**
   - APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: **Desktop app**
   - Name: `gmail-mcp`
   - Click Create → Download JSON
6. Place the downloaded file at:
   ```bash
   mv ~/Downloads/credentials.json ~/.config/gmail-mcp/credentials.json
   ```

##### 2. Run the HM module

```bash
home-manager switch --impure --flake ~/dotfiles#$(whoami)
```

This installs `uv` and `gmail-mcp-auth`, and writes the MCP config to `~/.config/opencode/opencode.json`.

##### 3. OAuth authorization

On a machine **with a browser**, this is one command:

```bash
uv run --no-project --with "mcp-google-gmail" --with "mcp>=1.8.0,<2" mcp-google-gmail auth
```

On a **headless SSH** machine, use the helper script:

```bash
# Step A: Generate auth URL
gmail-mcp-auth
```

This prints a URL. Open it in your local browser, sign in, click Continue, and grant Gmail permissions.
The browser will redirect to a broken `http://localhost/?code=...` page.

```bash
# Step B: Paste the redirect URL to exchange for a token
gmail-mcp-auth 'http://localhost/?code=4/0A...'
```

`token.json` is saved to `~/.config/gmail-mcp/token.json`.

##### 4. Verify

```bash
opencode mcp list
```

Should show `● ✓ gmail connected`.

##### 5. Use it

Ask OpenCode:
- *"Show my unread emails from today"*
- *"Search for emails about invoices from last week"*
- *"Send an email to me saying the PR is ready"*
- *"Find the email from john@example.com about the project update"*

</details>

### Firecrawl Setup

[`scripts/setup-firecrawl.sh`](scripts/setup-firecrawl.sh) saves your Firecrawl API key for the MCP server configured by [`firecrawl.nix`](#firecrawlnix):

```bash
# After home-manager switch --impure --flake ~/dotfiles
bash ~/dotfiles/scripts/setup-firecrawl.sh
```

The script will:
1. Create `~/.config/firecrawl/`
2. If `~/.config/firecrawl/api-key` already exists, prompt whether to overwrite it
3. Prompt for a key (`fc-...`, whitespace-trimmed) and save it to `~/.config/firecrawl/api-key` with `chmod 600`
4. Check the OpenCode config contains the Firecrawl MCP entry

Get your key from <https://www.firecrawl.dev/app/api-keys>. Restart OpenCode after setup so the MCP server picks up the key.

### Tailscale Setup

One-time setup to authenticate and enable Tailscale for auto-start on boot:

```bash
# After home-manager switch --impure --flake ~/dotfiles
bash ~/dotfiles/scripts/setup-tailscale.sh
```

The script will:
1. Start the `tailscaled` daemon (if not already running)
2. Run `tailscale up` — prints an auth URL to open in your browser
3. Verify the connection via `tailscale status`
4. Create and enable a systemd `tailscaled.service` unit for auto-start on boot
5. Write a `sudoers.d` file ensuring Nix binaries are on `secure_path` for sudo commands

> **macOS:** install the app (`brew install --cask tailscale`); the same script launches it and runs `tailscale up`. The app manages the daemon and auto-starts it at login — no systemd unit or `sudoers` file is created.

### Immich Setup

Immich runs as a Docker Compose stack configured by the [`immich.nix`](#immichnix) module. The compose file, `.env`, and directory scaffolding are created automatically on `home-manager switch`.

**Prerequisites:** Docker daemon and CLI (installed via Home Manager — see [packages.nix](#packagesnix)). On Linux an HDD mounted at `/mnt/hdd` stores photos; on macOS use Docker Desktop with the default `~/immich/library` location.

**First-time setup (Linux):**

```bash
# Link ~/immich/library -> /mnt/hdd/immich/library, start the daemon, pull, and start
make -C ~/dotfiles immich-setup
```

On a Debian system where the Docker daemon is not yet running, use the bootstrap script instead (it also works on macOS, starting Docker Desktop):

```bash
bash ~/dotfiles/scripts/setup-immich.sh
```

> **macOS:** the HDD/Samba/backup make targets are Linux-only and exit with a message. Start the stack with `bash scripts/setup-immich.sh` (or `make -C ~/dotfiles immich-start`); the compose file omits device passthrough and hardware acceleration.

Then open `http://<ip>:2283` to complete first-run setup.

**Managing the stack** (all commands via `make -C ~/dotfiles`):

| Command | Description |
|---|---|
| `immich-hdd-status` | Show whether `/mnt/hdd` is mounted and list USB disk info |
| `immich-hdd-mount` | Mount `/mnt/hdd` read-write (by UUID); moves auto-mounted drives, recovers stale and read-only mounts, and fails loudly if the mount is not rw |
| `immich-hdd-unmount` | Safely unmount `/mnt/hdd` |
| `immich-start` | Start containers (auto-mounts `/mnt/hdd`) |
| `immich-stop` | Stop containers (daemon stays running) |
| `immich-shutdown` | Stop containers and the Docker daemon |
| `immich-restart` | Restart containers |
| `immich-status` | Show container status |
| `immich-update` | Pull latest images and restart |
| `immich-backup` / `immich-restore` | Dump/restore the database to/from `~/immich/backups/` |
| `immich-sync DEST=DIR` | Sync all albums to an external drive, organized by album name |
| `immich-ip` | Print the Immich access URL |
| `immich-hdd-undo` / `immich-ssd-undo` | Restore all files deleted from the HDD/SSD Samba share recycle bins |
| `immich-hdd-backup` / `immich-ssd-backup` | Rotating snapshot backup of `/mnt/hdd` → `/mnt/ssd/backups/hdd` (and vice-versa) |

Run `make -C ~/dotfiles help` for the full list of targets.

> **Troubleshooting random unmounts:** The HDD is a USB drive (`My Passport`, UUID `7B6D-F242`, exFAT) mounted via `/etc/fstab` with `nofail`. When it drops off the USB bus (check with `sudo dmesg | grep -i usb`), the kernel may leave a **stale mount** at `/mnt/hdd` pointing to a dead device node — `ls /mnt/hdd/` then reports `Input/output error` even though `mountpoint` says mounted. `make immich-hdd-mount` detects this (the mount source no longer matches the live USB device) and remounts. Repeated `USB disconnect` lines in `dmesg` usually indicate a flaky cable, an under-powered USB port, or the enclosure's power management — try a different port/cable and a powered hub.

> **Troubleshooting "already mounted or mount point busy":** If `make immich-hdd-mount` fails with `mount: /dev/sda1 already mounted or mount point busy` plus `sda1: Can't mount, would change RO state`, the drive was auto-mounted elsewhere by the desktop session (udisks2/gvfs, usually under `/media/<user>/My Passport`) — often read-only after I/O errors. Run the one-time bootstrap to stop that auto-mount: `bash ~/dotfiles/scripts/init-setup-hdd.sh`, then re-plug the drive and run `make immich-hdd-mount` again. The target now also detects the other mountpoint and moves the drive to `/mnt/hdd`, and remounts a read-only `/mnt/hdd` rw *in place* without churning the mountpoint.

> **Auto-mounting on re-insert:** The udev rule installed by [`scripts/init-setup-hdd.sh`](scripts/init-setup-hdd.sh) also runs `systemctl --no-block restart mnt-hdd.mount` whenever the drive appears, so it re-mounts at `/mnt/hdd` (rw, owned by `ryuzaki`) on its own after an unplug/replug or USB drop — no manual step needed, and it's reachable over sftp. If a stale mount ever survives an abrupt unplug, the `restart` clears it. `make immich-hdd-mount` still works as a manual fallback.

### Filebrowser Setup

[`scripts/init-filebrowser.sh`](scripts/init-filebrowser.sh) is the one-shot, reproducible way to bring up Filebrowser. It is idempotent and safe to re-run, and works on both platforms:

```bash
bash ~/dotfiles/scripts/init-filebrowser.sh
```

It will:
1. Apply the Home Manager flake (installing `filebrowser` + the **systemd** unit on Linux or the **launchd** agent on macOS)
2. **Prompt interactively for the admin password** (hidden input, confirmed, min 8 chars) — unless `FILEBROWSER_PASSWORD` is already set in the environment
3. Ensure the Bolt DB exists, set the minimum password length to 8 and the TUS chunk size (default 2 GiB, override with `FILEBROWSER_TUS_CHUNK_SIZE`), then create-or-update the admin user
4. Start the service (on Linux it also enables **linger** via `sudo loginctl enable-linger` so the user service starts at boot without a login session)
5. Print the local and network access URLs

Access from another device: `http://<host-ip>:8080`.

**Environment overrides:** `FILEBROWSER_PASSWORD`, `FILEBROWSER_USERNAME` (default `admin`), `FILEBROWSER_TUS_CHUNK_SIZE` (default `2147483648`).

> **Note on boot persistence:** Home Manager fully manages the user-level unit (install, enable, restart on switch). The one thing it *cannot* do is enable **linger** — that's a root-level operation (`/var/lib/systemd/linger`), which is why the script performs it with `sudo`. Without linger, the service only starts once a desktop login session exists.

### Samba Shares

> **Linux-only.** macOS shares files through System Settings → General → Sharing; `scripts/init-setup-samba` exits with a message there.

[`scripts/init-setup-samba`](scripts/init-setup-samba) configures three Samba shares: the user's home share plus `hdd` (`/mnt/hdd`) and `ssd` (`/mnt/ssd`), accessible from the iPad via `smb://<ip>/hdd` and `smb://<ip>/ssd`. All shares use the `recycle` VFS module with `keeptree`, so deleted files land in a `.recycle` bin (`.recycle/<user>` for the home share) instead of being permanently removed. The `fruit`/`streams_xattr` modules for macOS/iPadOS compatibility (`ea support = yes`, `fruit:aapl = yes`) are only enabled where the backing filesystem supports extended attributes (the home share always; the `hdd`/`ssd` shares only on xattr-capable filesystems such as ext4 — skipped on exFAT/FAT32, where they'd break Apple-client directory listing).

**Restoring deleted files:**

```bash
make -C ~/dotfiles immich-hdd-undo   # restore files from /mnt/hdd/.recycle
make -C ~/dotfiles immich-ssd-undo   # restore files from /mnt/ssd/.recycle
```

These call [`scripts/samba-recycle-restore.sh`](scripts/samba-recycle-restore.sh), which snapshots the recycle bin to `<share>/.recycle-backups/<timestamp>` (so the undo itself is reversible), then moves every deleted item back to its original location. Items whose original path still exists are kept in the recycle bin.

**Rotating snapshot backups** (mirror each drive to the other, with hardlink deduplication and pruning of old snapshots via `KEEP=5` by default):

```bash
make -C ~/dotfiles immich-hdd-backup   # /mnt/hdd -> /mnt/ssd/backups/hdd
make -C ~/dotfiles immich-ssd-backup   # /mnt/ssd -> /mnt/hdd/backups/ssd
```

Both call [`scripts/backup-drive.sh`](scripts/backup-drive.sh), which creates `YYYYMMDD-HHMMSS` snapshots and keeps the newest `KEEP` (default 5).

### Exposing OpenCode on the Tailnet

Two companion scripts make OpenCode accessible on the tailnet:

- **`scripts/opencode-serve.sh`** — Starts `opencode serve` on all interfaces and exposes it via `tailscale serve`, making the OpenCode API available to other devices on your tailnet.
- **`scripts/opencode-gateway.py`** — A lightweight HTTP gateway that accepts prompts via `GET`/`POST` and proxies them to the `opencode serve` API. Supports query params, JSON body, form-encoded, and raw text payloads.

```bash
# Start the serve + tailscale tunnel
bash ~/dotfiles/scripts/opencode-serve.sh

# Query via the gateway (runs on port 8080 by default)
curl -d 'Summarize the last 3 git commits' http://localhost:8080
```

### Interview-Prep EPUB Builds

[`scripts/build-epubs.sh`](scripts/build-epubs.sh) (aliased `build-epubs`) converts the `~/interview-prep` markdown tree into EPUB books. It uses only profile tools (declared in [`epub.nix`](#epubnix) plus `pandoc`), never modifies the source tree, and validates every book before finishing:

```bash
build-epubs                       # ~/interview-prep -> ~/interview-prep-epub
build-epubs SRC OUT               # explicit source and output directories
```

It produces one EPUB per directory that directly contains markdown (mirroring the tree) and one master `interview-prep.epub` containing every file. A generated `epub.css` embeds `DejaVu Sans Mono` for code and box-drawing diagrams; [`scripts/epub-preprocess.py`](scripts/epub-preprocess.py) sanitizes each file first (flattening raw HTML Q&A blocks, rewriting internal links to anchors, relabeling mermaid/box-drawing fences) so `epubcheck` passes. Overridable via `SRC`, `OUT`, `AUTHOR`, and `LANG_CODE` environment variables.

## Usage

| Command | Description |
|---|---|
| `rebuild-home-manager` | Apply the current configuration (auto-detects username) |
| `update-home-manager` | Update flake lockfile and apply |
| `nixvim` | Launch the Nixvim editor |
| `search <query>` | Search for packages in nixpkgs |
| `clock` | Show a live clock in the terminal |
| `display <image>` | Render an image in the terminal via kitty protocol |
| `dot` | `cd ~/dotfiles` |
| `edot` | Open dotfiles in Nixvim |
| `ga` | `git add .` |
| `yt` | Download a 4K video via `download-vid.sh` |
| `build-epubs` | Build EPUB books from the ~/interview-prep markdown tree |
| `crt` | Stylise a video with a CRT/VHS look (`retrocrt`) |
| `ghostty-set-theme` | Pick a Ghostty theme via fzf (live preview); `--reset` for the default |
| `generate-ssh-key` | Generate an Ed25519 SSH key for a given email |
| `bash ~/dotfiles/scripts/install-nix.sh` | Install the official multi-user Nix on Linux and macOS (`--daemon`) |
| `bash ~/dotfiles/scripts/init-home-manager.sh` | Apply the flake and set Fish as the login shell (no reboot on macOS) |
| `bash ~/dotfiles/scripts/download-vid.sh` | Download a 4K video from a URL using yt-dlp + ffmpeg |
| `bash ~/dotfiles/scripts/setup-tailscale.sh` | Authenticate Tailscale (systemd unit on Linux, app on macOS) |
| `bash ~/dotfiles/scripts/opencode-serve.sh` | Expose OpenCode on the tailnet |
| `make -C ~/dotfiles immich-setup` | First-time Immich setup (start daemon, link library, pull, start) — *Linux* |
| `bash ~/dotfiles/scripts/setup-immich.sh` | Bootstrap the Docker daemon and start Immich (Debian/macOS) |
| `bash ~/dotfiles/scripts/setup-firecrawl.sh` | Save a Firecrawl API key for the MCP server (`~/.config/firecrawl/api-key`) |
| `bash ~/dotfiles/scripts/init-filebrowser.sh` | One-shot reproducible Filebrowser setup (systemd on Linux / launchd on macOS) |
| `bash ~/dotfiles/scripts/add-subtitles.sh VIDEO srt` | Embed an `.srt` into a video as a soft subtitle track (`mov_text`) |
| `bash ~/dotfiles/scripts/init-setup-hdd.sh` | Stop desktop auto-mount of the Immich HDD + auto-mount it at `/mnt/hdd` on re-insert (one-time) — *Linux* |
| `make -C ~/dotfiles immich-sync DEST=DIR` | Sync Immich albums to an external drive |
| `make -C ~/dotfiles immich-hdd-mount` | Mount `/mnt/hdd` rw (moves auto-mounted drives, recovers stale/read-only mounts) — *Linux* |
| `make -C ~/dotfiles immich-hdd-undo` / `immich-ssd-undo` | Restore Samba recycle-bin deletes on `/mnt/hdd` / `/mnt/ssd` — *Linux* |
| `make -C ~/dotfiles immich-hdd-backup` / `immich-ssd-backup` | Rotating snapshot backup of `/mnt/hdd` ↔ `/mnt/ssd` — *Linux* |
| `home-manager expire-generations 30d` | Garbage collect old Home Manager generations |

> **Linux-only:** the HDD-mount, Samba recycle-bin, and drive-backup targets/scripts above exit with an explanatory message on macOS (no `/mnt/hdd`, no Samba server).

## Acknowledgements

- [Home Manager](https://github.com/nix-community/home-manager) — Managing the user environment declaratively
- [Nixvim](https://github.com/nix-community/nixvim) — Neovim distribution configured in Nix
- [Obsitui](https://github.com/atr0t0s/obsitui) — Terminal UI for Obsidian vaults
- [Basalt](https://github.com/atr0t0s/basalt) — Obsidian TUI with vim keybindings
