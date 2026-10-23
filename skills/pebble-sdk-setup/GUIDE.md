# Pebble environment setup and verification

## 1. Health check

Run `scripts/check-env.sh`. It checks:

- host OS/architecture,
- `pebble --version`,
- `pebble sdk list` (installed and active),
- `qemu-pebble --version`,
- `mcrun` presence through the SDK toolchain,
- `pebble-python -c 'import PIL'`,
- `node`/`npm`,
- the expected SDK symlink (`SDKs/current`),
- no stale `pebble sdk install` artifacts.

## 2. Nix/home-manager repair

The canonical setup is in `~/dotfiles`:

- `flake.nix` input: `github:pebble-dev/pebble.nix`
- `modules/common/pebble.nix`: installs `pebble-tool`, the SDK package, the QEMU wrapper, and `pebble-python`
- `pkgs/pebble-sdk/`: SDK core + toolchain + Python/Node environments
- declarative `SDKs/4.33.1` and `SDKs/current` symlinks

Apply:

```bash
cd ~/dotfiles
git status --short
git add flake.nix flake.lock modules/common/default.nix modules/common/pebble.nix pkgs/pebble-sdk
home-manager switch --impure --flake ~/dotfiles#$(whoami)
```

Do not run `pebble sdk install`.

## 3. Smoke test

Use a temporary directory, not the user's project:

```bash
cd /tmp
pebble new-project --ai pebble-env-smoke
cd pebble-env-smoke
pebble build
pebble install --emulator emery
# If the first install reports Connection refused while pypkjs/websockify start,
# rerun the same install; it reuses the running emulator.
pebble screenshot --no-open --emulator emery smoke.png
pebble logs --emulator emery
pebble kill
```

Expected:
- `build/pebble-env-smoke.pbw`
- `smoke.png` shows the app, not a stale launcher
- logs contain no crash
- no network SDK install occurred

## 4. Report

Return:
- `pebble --version`
- `pebble sdk list` first block
- `qemu-pebble --version`
- Python/Pillow result
- smoke test pass/fail
- any remaining caveat (e.g., first QEMU launch is slow)
