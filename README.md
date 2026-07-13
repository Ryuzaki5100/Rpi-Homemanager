# dotfiles

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos&logoColor=white)](https://nixos.org)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-25.11-green?logo=nixos&logoColor=white)](https://github.com/nix-community/home-manager)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Arch](https://img.shields.io/badge/arch-aarch64--linux-red)](#)

Personal Home Manager configuration for a terminal-centric workflow on `aarch64-linux`. This flake manages user-level packages, shell configuration, environment variables, and Obsidian TUI tooling — all without any NixOS system-level configuration.

## Table of Contents

- [Architecture](#architecture)
- [Structure](#structure)
- [Modules](#modules)
  - [core.nix](#corenix)
  - [env.nix](#envnix)
  - [fish.nix](#fishnix)
  - [packages.nix](#packagesnix)
  - [obsidian.nix](#obsidiannix)
- [Custom Packages](#custom-packages)
  - [nixvim-editor](#nixvim-editor)
  - [obsitui](#obsitui)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)

## Architecture

```
flake.nix  ──►  home.nix  ──►  modules/*.nix
                      │
                      └── pkgs/
                            ├── nixvim-editor.nix
                            └── obsitui.nix
```

| Layer | Description |
|---|---|
| **`flake.nix`** | Entry point. Pins `nixpkgs` (nixos-unstable) and `home-manager`. Builds custom packages and passes them as `extraSpecialArgs` into the module tree. |
| **`home.nix`** | Thin shim; imports all five modules under `modules/`. Receives `obsitui` and `nixvim-editor` as extra arguments. |
| **`modules/`** | Self-contained Nix files, each responsible for one concern. |
| **`pkgs/`** | Custom package derivations exported both as flake outputs and installed in the Home Manager profile. |

### Dependencies

| Input | Source |
|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` |
| `home-manager` | `github:nix-community/home-manager` (follows `nixpkgs`) |

### Custom Packages as Flake Outputs

Both `obsitui` and `nixvim-editor` are exposed under `packages.aarch64-linux`, making them usable from outside this flake:

```bash
nix run github:Ryuzaki5100/dotfiles#obsitui
nix run github:Ryuzaki5100/dotfiles#nixvim-editor
```

## Structure

```
dotfiles/
├── flake.nix              # Flake entry point, inputs, outputs
├── flake.lock             # Locked dependency revisions
├── home.nix               # Top-level Home Manager module
├── modules/
│   ├── core.nix           # User identity & state version
│   ├── env.nix            # Session environment variables
│   ├── fish.nix           # Fish shell config & aliases
│   ├── packages.nix       # Declarative package list
│   └── obsidian.nix       # Obsidian vaults & Basalt config
└── pkgs/
    ├── nixvim-editor.nix  # Thin wrapper around external Nixvim flake
    └── obsitui.nix        # Obsidian TUI from source (npm)
```

## Modules

### core.nix

Sets the user identity and Home Manager state version.

```nix
home.username      = "ryuzaki";
home.homeDirectory = "/home/ryuzaki";
home.stateVersion  = "25.11";
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
- Sources the Nix daemon profile for environment integration
- Re-exports `EDITOR` for shell sessions
- Binds autosuggestion acceptance to multiple keys: **Ctrl+Space**, **Alt+Space**, **Alt+.**, and **Shift+Tab**

**Aliases:**

| Alias | Command |
|---|---|
| `nixvim` | `nix run github:Ryuzaki5100/nixvim --refresh` |
| `rebuild-home-manager` | `home-manager switch --flake ~/dotfiles#ryuzaki` |
| `update-home-manager` | `cd ~/dotfiles && nix flake update && cd -` |
| `display` | `chafa -f kitty --fit-width` |
| `clock` | `clock-rs -c bright-black -B -b` |

### packages.nix

Declarative package list installed via `home.packages`. Grouped by category:

| Category | Packages |
|---|---|
| Editors | `neovim`, `code-server`, `opencode` |
| Dev tools | `lazygit`, `tmux` |
| System info | `fastfetch`, `nitch`, `btop`, `clock-rs` |
| Media & graphics | `chafa`, `timg`, `mpv`, `ffmpeg`, `yt-dlp`, `yazi` |
| Networking & chat | `browsh`, `nchat`, `bluetuith`, `wifitui`, `reddit-tui`, `smassh`, `gemini-cli` |
| Obsidian TUIs | `basalt`, `obsitui`, `nixvim-editor` |
| Fun | `cmatrix` |

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

## Custom Packages

### nixvim-editor

A lightweight `writeShellScriptBin` wrapper that delegates to the user's [Nixvim](https://github.com/Ryuzaki5100/nixvim) flake. Every invocation fetches the latest build (`--refresh`), ensuring the editor is always up to date without manual intervention.

```
nix run github:Ryuzaki5100/nixvim --refresh -- "$@"
```

Used as the system `EDITOR` and referenced by Basalt keybindings for opening notes.

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

### Installation

```bash
# Clone the repository
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles

# Build and activate the Home Manager configuration
home-manager switch --flake ~/dotfiles#ryuzaki
```

### Updating dependencies

```bash
cd ~/dotfiles && nix flake update && home-manager switch --flake .#ryuzaki
```

Both commands are aliased as `rebuild-home-manager` and `update-home-manager` for convenience.

## Usage

| Command | Description |
|---|---|
| `rebuild-home-manager` | Apply the current configuration |
| `update-home-manager` | Update flake lockfile and apply |
| `nixvim` | Launch the Nixvim editor |
| `display <image>` | Render an image in the terminal via kitty protocol |
| `clock` | Display a digital clock in the terminal |
| `home-manager expire-generations 30d` | Garbage collect old Home Manager generations |

## Acknowledgements

- [Home Manager](https://github.com/nix-community/home-manager) — Managing the user environment declaratively
- [Nixvim](https://github.com/nix-community/nixvim) — Neovim distribution configured in Nix
- [Obsitui](https://github.com/atr0t0s/obsitui) — Terminal UI for Obsidian vaults
- [Basalt](https://github.com/atr0t0s/basalt) — Obsidian TUI with vim keybindings
