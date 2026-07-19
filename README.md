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
  - [opencode.nix](#opencodenix)
  - [packages.nix](#packagesnix)
  - [gmail-mcp.nix](#gmail-mcpnix)
  - [obsidian.nix](#obsidiannix)
- [Custom Packages](#custom-packages)
  - [nixvim-editor](#nixvim-editor)
  - [gmail-mcp-auth](#gmail-mcp-auth)
  - [obsitui](#obsitui)
- [Quick Start](#quick-start)
  - [Gmail MCP Setup](#gmail-mcp-setup)
  - [Tailscale Setup](#tailscale-setup)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)

## Architecture

```
flake.nix  ──►  home.nix  ──►  modules/*.nix
                      │
                      ├── pkgs/
                      │     ├── nixvim-editor.nix
                      │     ├── obsitui.nix
                      │     └── gmail-mcp-auth.nix
                      │
                      └── skills/
                            ├── skill-creator/SKILL.md
                            └── update-docs/SKILL.md
```

| Layer | Description |
|---|---|
| **`flake.nix`** | Entry point. Pins `nixpkgs` (nixos-unstable) and `home-manager`. Builds custom packages and passes them as `extraSpecialArgs` into the module tree. |
| **`home.nix`** | Thin shim; imports all eight modules under `modules/`. Receives custom packages as extra arguments. |
| **`modules/`** | Self-contained Nix files, each responsible for one concern. |
| **`pkgs/`** | Custom package derivations exported both as flake outputs and installed in the Home Manager profile. |
| **`skills/`** | OpenCode skill definitions (SKILL.md files) deployed via `xdg.configFile` symlinks. |

### Dependencies

| Input | Source |
|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` |
| `home-manager` | `github:nix-community/home-manager` (follows `nixpkgs`) |

### Custom Packages as Flake Outputs

Custom packages are exposed under `packages.aarch64-linux`, making them usable from outside this flake:

```bash
nix run github:Ryuzaki5100/dotfiles#obsitui
nix run github:Ryuzaki5100/dotfiles#nixvim-editor
nix run github:Ryuzaki5100/dotfiles#gmail-mcp-auth
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
│   ├── gmail-mcp.nix      # Gmail MCP auth packages
│   ├── obsidian.nix       # Obsidian vaults & Basalt config
│   ├── opencode.nix       # OpenCode config & MCP settings
│   └── packages.nix       # Declarative package list
├── pkgs/
│   ├── gmail-mcp-auth.nix # Wrapper around gmail-mcp-auth.py (python + google-auth-oauthlib)
│   ├── nixvim-editor.nix  # Thin wrapper around external Nixvim flake
│   └── obsitui.nix        # Obsidian TUI from source (npm)
├── scripts/
│   ├── gmail-mcp-auth.py      # Headless OAuth helper for Gmail MCP
│   ├── init-home-manager.sh   # Bootstrap Home Manager on a fresh system
│   ├── init-setup-samba       # Samba initial setup
│   ├── opencode-gateway.py    # HTTP gateway proxy to opencode serve
│   ├── opencode-serve.sh      # Launch opencode serve and expose on tailnet
│   ├── download-vid.sh        # Download 4K video with yt-dlp and ffmpeg
│   ├── setup-gmail-mcp.sh     # Interactive Gmail MCP setup wizard
│   ├── setup-rpi-usb-gadget.sh # Configure RPi as USB ethernet gadget
│   └── setup-tailscale.sh     # Tailscale auth, status check, and systemd enable
└── skills/
    ├── skill-creator/     # OpenCode skill: interactive skill creation wizard
    └── update-docs/       # OpenCode skill: auto-update docs from git changes
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
| `search` | `nix search nixpkgs` |
| `clock` | `clock-rs -c bright-black -B -b` |
| `display` | `chafa -f kitty --fit-width` |
| `edot` | `cd ~/dotfiles && nixvim` |
| `dot` | `cd ~/dotfiles` |
| `ga` | `git add .` |

### opencode.nix

Configures [OpenCode](https://opencode.ai) — an AI coding assistant — via `programs.opencode`.

**Model:** Default model set to `opencode/deepseek-v4-flash-free`.

**MCP server configuration:**
- Defines a Gmail MCP server using `mcp-google-gmail` with paths to OAuth credentials and token
- The MCP server is **disabled by default** — enable with `opencode mcp toggle gmail` or set `programs.opencode.settings.mcp.gmail.enabled = true`

**Skill deployment:**
- Automatically discovers subdirectories under `skills/` and symlinks each `SKILL.md` into `~/.config/opencode/skills/<name>/`
- This makes locally-developed skills available to OpenCode without manual copying

### packages.nix

Declarative package list installed via `home.packages`. Grouped by category:

| Category | Packages |
|---|---|
| Editors | `neovim`, `code-server`, `opencode` |
| Dev tools | `lazygit`, `tmux` |
| System info | `fastfetch`, `nitch`, `btop`, `clock-rs` |
| Media & graphics | `chafa`, `timg`, `mpv`, `ffmpeg`, `yt-dlp`, `yazi`, `pandoc`, `localsend`, `jocalsend` |
| Networking & chat | `browsh`, `nchat`, `bluetuith`, `wifitui`, `tailscale`, `reddit-tui`, `reddix`, `discordo`, `wiki-tui`, `hackernews-tui`, `youtube-tui`, `smassh`, `gemini-cli`, `mangal` |
| Obsidian TUIs | `basalt`, `obsitui`, `nixvim-editor` |
| Flashcards | `srl-tui` |
| Fun | `cmatrix`, `posting` |

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
home-manager switch --flake ~/dotfiles#ryuzaki
# Copy credentials.json to ~/.config/gmail-mcp/credentials.json
bash ~/dotfiles/scripts/setup-gmail-mcp.sh
```

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

### Installation

**On an existing Home Manager setup:**

```bash
# Clone the repository
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles

# Build and activate the Home Manager configuration
home-manager switch --flake ~/dotfiles#ryuzaki
```

**On a fresh system (bootstraps flakes + Home Manager):**

```bash
git clone https://github.com/Ryuzaki5100/dotfiles ~/dotfiles
bash ~/dotfiles/scripts/init-home-manager.sh
```

### Updating dependencies

```bash
cd ~/dotfiles && nix flake update && home-manager switch --flake .#ryuzaki
```

Both commands are aliased as `rebuild-home-manager` and `update-home-manager` for convenience.

### Gmail MCP Setup

Two paths: **automated** (recommended) or **manual** (understanding).

#### Automated (script)

```bash
# After home-manager switch --flake ~/dotfiles
bash ~/dotfiles/scripts/setup-gmail-mcp.sh
```

The script will:
1. Verify `uv` and `gmail-mcp-auth` are installed
2. Create `~/.config/gmail-mcp/`
3. If `credentials.json` is missing, prompt you to set it up
4. If `token.json` is missing, run the OAuth flow (prints URL → you authorize → paste redirect URL)
5. Verify the MCP server is connected

> **Note:** The MCP server is disabled by default. After setup, enable it with
> `opencode mcp toggle gmail`, or set `programs.opencode.settings.mcp.gmail.enabled = true`
> in your flake configuration.

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
home-manager switch --flake ~/dotfiles#ryuzaki
```

This installs `uv` and `gmail-mcp-auth`, and writes the MCP config to `~/.config/opencode/opencode.json`.

##### 3. OAuth authorization

On a machine **with a browser**, this is one command:

```bash
uvx mcp-google-gmail@latest auth
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

### Tailscale Setup

One-time setup to authenticate and enable Tailscale for auto-start on boot:

```bash
# After home-manager switch --flake ~/dotfiles
bash ~/dotfiles/scripts/setup-tailscale.sh
```

The script will:
1. Start the `tailscaled` daemon (if not already running)
2. Run `tailscale up` — prints an auth URL to open in your browser
3. Verify the connection via `tailscale status`
4. Create and enable a systemd `tailscaled.service` unit for auto-start on boot
5. Write a `sudoers.d` file ensuring Nix binaries are on `secure_path` for sudo commands

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

## Usage

| Command | Description |
|---|---|
| `rebuild-home-manager` | Apply the current configuration |
| `update-home-manager` | Update flake lockfile and apply |
| `nixvim` | Launch the Nixvim editor |
| `search <query>` | Search for packages in nixpkgs |
| `clock` | Show a live clock in the terminal |
| `display <image>` | Render an image in the terminal via kitty protocol |
| `dot` | `cd ~/dotfiles` |
| `edot` | Open dotfiles in Nixvim |
| `ga` | `git add .` |
| `bash ~/dotfiles/scripts/download-vid.sh` | Download a 4K video from a URL using yt-dlp + ffmpeg |
| `bash ~/dotfiles/scripts/setup-tailscale.sh` | Authenticate Tailscale and enable auto-start on boot |
| `bash ~/dotfiles/scripts/opencode-serve.sh` | Expose OpenCode on the tailnet |
| `home-manager expire-generations 30d` | Garbage collect old Home Manager generations |

## Acknowledgements

- [Home Manager](https://github.com/nix-community/home-manager) — Managing the user environment declaratively
- [Nixvim](https://github.com/nix-community/nixvim) — Neovim distribution configured in Nix
- [Obsitui](https://github.com/atr0t0s/obsitui) — Terminal UI for Obsidian vaults
- [Basalt](https://github.com/atr0t0s/basalt) — Obsidian TUI with vim keybindings
