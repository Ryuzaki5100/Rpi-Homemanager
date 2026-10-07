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
  - [glow.nix](#glownix)
  - [epub.nix](#epubnix)
- [Skills](#skills)
- [Custom Packages](#custom-packages)
  - [nixvim-editor](#nixvim-editor)
  - [bitchat-cli](#bitchat-cli)
  - [gmail-mcp-auth](#gmail-mcp-auth)
  - [obsitui](#obsitui)
- [Quick Start](#quick-start)
  - [macOS Support](#macos-support)
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
                      │     ├── nixvim-editor.nix
                      │     ├── obsitui.nix
                      │     ├── gmail-mcp-auth.nix
                      │     └── bitchat-cli.nix
                      │
                      └── skills/
                            ├── ai-era-mock-interview/SKILL.md
                            ├── batch-resume-tailor/SKILL.md
                            ├── daily-prep-questions/SKILL.md
                            ├── glow-theme-creator/SKILL.md
                            ├── hld-problems-generator/SKILL.md
                            ├── single-resume-tailor/SKILL.md
                            ├── skill-creator/SKILL.md
                            ├── system-design-tester/SKILL.md
                            ├── system-design-tutor/SKILL.md
                            ├── update-docs/SKILL.md
                            └── yt-summarizer/SKILL.md
```

| Layer | Description |
|---|---|
| **`flake.nix`** | Entry point. Pins `nixpkgs` (nixos-unstable) and `home-manager`. Builds custom packages per system (`packages.<system>` for `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`) and passes them as `extraSpecialArgs` into the module tree. The `homeConfigurations.<user>` output targets the current host. |
| **`home.nix`** | Thin shim; imports `modules/` and sets shared `nixpkgs.config`. |
| **`modules/default.nix`** | The single platform-selection point. Imports `common/` always, plus the matching platform layer(s) based on `pkgs.stdenv.hostPlatform`. |
| **`modules/common/`** | Modules and packages that build on **every** platform. |
| **`modules/linux/`, `linux-aarch64/`, `darwin/`** | Platform-specific packages and services (see [Platform layers](#platform-layers)). |
| **`pkgs/`** | Custom package derivations exported both as flake outputs and installed in the Home Manager profile. |
| **`skills/`** | OpenCode skill definitions (`SKILL.md` files, plus optional `GUIDE.md` companions) deployed via `xdg.configFile` symlinks. |

### Dependencies

| Input | Source |
|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` |
| `home-manager` | `github:nix-community/home-manager` (follows `nixpkgs`) |

### Custom Packages as Flake Outputs

Custom packages are exposed under `packages.<system>` (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`), making them usable from outside this flake:

```bash
nix run github:Ryuzaki5100/dotfiles#obsitui
nix run github:Ryuzaki5100/dotfiles#nixvim-editor
nix run github:Ryuzaki5100/dotfiles#gmail-mcp-auth
nix run github:Ryuzaki5100/dotfiles#bitchat-cli
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
│       └── packages.nix       # macOS-only package set
├── glow/
│   └── themes/            # glamour v2 theme JSONs (retro-orange, gruvbox, nord, tokyo-night, catppuccin-mocha, dracula, blood-red)
├── pkgs/
│   ├── bitchat-cli.nix    # bitchat CLI (PyPI, buildPythonApplication)
│   ├── gmail-mcp-auth.nix # Wrapper around gmail-mcp-auth.py (python + google-auth-oauthlib)
│   ├── nixvim-editor.nix  # Thin wrapper around external Nixvim flake
│   └── obsitui.nix        # Obsidian TUI from source (npm)
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
│   ├── samba-recycle-restore.sh # Restore files from a Samba recycle bin
│   ├── setup-gmail-mcp.sh     # Interactive Gmail MCP setup wizard
│   ├── setup-firecrawl.sh     # Save a Firecrawl API key for the MCP server
│   ├── setup-immich.sh        # Bootstrap Docker daemon and start Immich
│   ├── setup-rpi-usb-gadget.sh # Configure RPi as USB ethernet gadget
│   ├── setup-tailscale.sh     # Tailscale auth, status check, and systemd enable
│   ├── setup-wayvnc.sh        # Set up WayVNC VNC server for iPad access
│   └── sync-to-ssd.sh         # Sync Immich albums to an external drive
└── skills/
    ├── ai-era-mock-interview/ # OpenCode skill: AI-era mock interview on a buggy Java/Maven codebase
    ├── batch-resume-tailor/ # OpenCode skill: batch tailor resumes from job posting URLs
    ├── daily-prep-questions/ # OpenCode skill: daily no-repeat interview-prep set (LC/SD/behavioral/SQL/LLD)
    ├── glow-theme-creator/ # OpenCode skill: build glow themes from a described vibe
    ├── hld-problems-generator/ # OpenCode skill: synthesize HLD practice problems + EPUB
    ├── single-resume-tailor/ # OpenCode skill: ATS-optimized one-page resume from a JD
    ├── skill-creator/     # OpenCode skill: interactive skill creation wizard
    ├── system-design-tester/ # OpenCode skill: generate timestamped SD test papers
    ├── system-design-tutor/ # OpenCode skill: answer keys, grading, and reasoning for SD tests
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
| `darwin/` | `pkgs.stdenv.hostPlatform.isDarwin` | macOS packages and the launchd Filebrowser agent |

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

Exports a single session variable:

| Variable | Value |
|---|---|
| `EDITOR` | `nixvim-editor` |

### fish.nix

Configures Fish as the login shell.

**Interactive shell initialisation:**
- Sources the Nix daemon profile for environment integration (existence-guarded so it works on both Nix and the Determinate installer)
- Re-exports `EDITOR` for shell sessions
- Binds autosuggestion acceptance to multiple keys: **Ctrl+Space**, **Alt+Space**, **Alt+.**, and **Shift+Tab**

**Aliases:**

| Alias | Command |
|---|---|
| `nixvim` | `nix run github:Ryuzaki5100/nixvim --refresh` |
| `rebuild-home-manager` | `home-manager switch --impure --flake ~/dotfiles#(whoami) && exec fish` |
| `update-home-manager` | `cd ~/dotfiles && nix flake update && cd -` |
| `search` | `nix search nixpkgs` |
| `clock` | `clock-rs -c bright-black -B -b` |
| `display` | `chafa -f kitty --fit-width` |
| `edot` | `cd ~/dotfiles && nixvim` |
| `dot` | `cd ~/dotfiles` |
| `ga` | `git add .` |
| `op` | `opencode` |
| `yt` | `~/dotfiles/scripts/download-vid.sh` |
| `build-epubs` | `~/dotfiles/scripts/build-epubs.sh` |

**Functions:**

| Function | Description |
|---|---|
| `generate-ssh-key` | Prompts for an email and generates an Ed25519 SSH key (`ssh-keygen -t ed25519 -C "<email>"`) |
| `rebuild-nixos` | Rebuilds the NixOS system from `~/rpi-nixos` via `nixos-rebuild switch --flake`. Gracefully errors if not on NixOS or the flake directory is missing. |
| `update-nixos` | Updates the flake lock for `~/rpi-nixos`. Harmless on non-NixOS hosts. |

### opencode.nix

Configures [OpenCode](https://opencode.ai) — an AI coding assistant — via `programs.opencode`.

**Model:** Default model set to `opencode/deepseek-v4-flash-free`.

**MCP server configuration:**
- Defines a Gmail MCP server using `mcp-google-gmail` with paths to OAuth credentials and token
- The server is **enabled by default** — set `programs.opencode.settings.mcp.gmail.enabled = false` to disable it
- Launches via `uv run --no-project --with "mcp-google-gmail" --with "mcp>=1.8.0,<2" mcp-google-gmail`, pinning `mcp<2` because `mcp-google-gmail` requires the `fastmcp` module that was removed in `mcp` 2.0.0
- Defines a Firecrawl MCP server (`firecrawl-mcp`, **enabled**, keyed on `~/.config/firecrawl/api-key`) — see [`firecrawl.nix`](#firecrawlnix)

**Skill deployment:**
- Automatically discovers subdirectories under `skills/` and symlinks each `SKILL.md` into `~/.config/opencode/skills/<name>/`
- Any `GUIDE.md` found alongside a `SKILL.md` is symlinked too, so candidate/human-facing guides (e.g. [`ai-era-mock-interview`](#ai-era-mock-interview)) ship with the skill
- This makes locally-developed skills available to OpenCode without manual copying

### packages.nix

Declarative cross-platform package list installed via `home.packages` from [`modules/common/packages.nix`](modules/common/packages.nix). Grouped by category (Linux-only extras noted in parentheses):

| Category | Packages |
|---|---|
| Editors | `neovim`, `opencode` (`code-server` on Linux) |
| Dev tools | `lazygit`, `tmux`, `zellij`, `fzf`, `jdk`, `maven` |
| Containers | `docker`, `docker-compose`, `jq` |
| System info | `fastfetch`, `btop`, `clock-rs`, `smartmontools` (`nitch` on Linux) |
| Media & graphics | `chafa`, `timg`, `mpv`, `ffmpeg`, `yt-dlp`, `yazi`, `pandoc`, `dysk`, `nix-search-tv` (`foliate` on Linux) |
| Networking & chat | `browsh`, `nchat`, `bitchat-cli`, `tailscale`, `reddit-tui`, `reddix`, `discordo`, `wiki-tui`, `hackernews-tui`, `youtube-tui`, `smassh`, `gemini-cli`, `mangal` (`bluetuith`, `wifitui` on Linux) |
| Obsidian TUIs | `basalt`, `obsitui`, `glow`, `nixvim-editor` |
| Fun | `cmatrix`, `posting`, `asciiquarium` |

Platform-specific packages live in [`modules/linux/packages.nix`](modules/linux/packages.nix) (`code-server`, `nitch`, `bluetuith`, `wifitui`, `exfatprogs`, `foliate`) and [`modules/darwin/packages.nix`](modules/darwin/packages.nix). macOS uses `fastfetch` in place of `nitch`, and native Bluetooth/Wi-Fi/exFAT in place of the Linux TUIs.

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

## Skills

OpenCode skills are stored in `skills/` and auto-deployed to `~/.config/opencode/skills/<name>/` by the [`opencode.nix`](#opencodenix) module (any subdirectory with a `SKILL.md` is symlinked automatically).

### skill-creator

Interactive wizard for creating new OpenCode skills — guides the agent through naming, scoping, and writing a `SKILL.md` in `skills/<name>/`.

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

## Custom Packages

### nixvim-editor

A lightweight `writeShellScriptBin` wrapper that delegates to the user's [Nixvim](https://github.com/Ryuzaki5100/nixvim) flake. Every invocation fetches the latest build (`--refresh`), ensuring the editor is always up to date without manual intervention.

```
nix run github:Ryuzaki5100/nixvim --refresh -- "$@"
```

Used as the system `EDITOR` and referenced by Basalt keybindings for opening notes.

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

## Quick Start

### Prerequisites

- Nix with flakes enabled (`nix-command` and `flakes` experimental features)
- Home Manager installed

> **On a truly fresh system without Nix**, run `bash ~/dotfiles/scripts/install-nix.sh` first.
> It installs the official multi-user (`--daemon`) installer on Linux and the
> Determinate Systems installer on macOS, then log out and back in before proceeding.

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

### Updating dependencies

```bash
cd ~/dotfiles && nix flake update && home-manager switch --impure --flake .#$(whoami)
```

Both commands are aliased as `rebuild-home-manager` and `update-home-manager` for convenience.

### macOS Support

The configuration is layered so Home Manager builds only the modules the host can run — see [Platform layers](#platform-layers). On Apple Silicon:

1. **Install Nix** (Determinate installer):
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
> `programs.opencode.settings.mcp.gmail.enabled = true`
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
| `generate-ssh-key` | Generate an Ed25519 SSH key for a given email |
| `bash ~/dotfiles/scripts/install-nix.sh` | Install Nix (official `--daemon` on Linux, Determinate on macOS) |
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
