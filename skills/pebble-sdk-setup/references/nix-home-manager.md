# Nix/home-manager wiring

## Files

```text
~/dotfiles/
  flake.nix                         # pebble input + extraSpecialArgs
  modules/common/default.nix        # imports ./pebble.nix
  modules/common/pebble.nix         # packages, env vars, SDK symlinks
  pkgs/pebble-sdk/default.nix       # SDK core + toolchain + Python/Node env
  pkgs/pebble-sdk/node/             # package.json + package-lock.json
  pkgs/pebble-tool.nix              # pebble-tool + emulator patches
  pkgs/pypkjs.nix                   # pypkjs with fixed stpyv8 hash
```

## flake.nix

```nix
inputs.pebble = {
  url = "github:pebble-dev/pebble.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pass it to the Home Manager modules:

```nix
extraSpecialArgs = {
  inherit pkgs;
  inherit (pkgs) obsitui nixvim-editor;
  inherit pebble;
};
```

## modules/common/pebble.nix

- Installs a `pebble` wrapper around `pkgs.pebble-tool`, with `PYTHONPATH` set for pypkjs/websockify and `PEBBLE_QEMU_PATH` pinned to the Nix QEMU.
- Installs `pkgs.pebble-sdk`.
- Adds a `qemu-pebble` wrapper around `pebble.packages.${system}.pebble-qemu` (Nix-built QEMU).
- Adds `pebble-python` with Pillow.
- Sets `PEBBLE_QEMU_PATH`, `PEBBLE_EMULATOR`, `PEBBLE_PYTHON`.
- Copies the Nix SDK into a writable tree (Waf writes a helper there):
  - `~/Library/Application Support/Pebble SDK/SDKs/4.33.1/{sdk-core,toolchain}` on macOS
  - `~/.pebble-sdk/SDKs/4.33.1/...` on Linux
- Links `.venv` and `node_modules` to the Nix environments.
- Points `SDKs/current` at the writable copy.

## Apply

```bash
cd ~/dotfiles
git add flake.nix flake.lock modules/common/default.nix modules/common/pebble.nix pkgs/pebble-sdk skills
home-manager switch --impure --flake ~/dotfiles#$(whoami)
```

Flakes ignore untracked files, so `git add` is mandatory for new skill/package files.

## Verify

```bash
pebble --version
pebble sdk list
qemu-pebble --version
mcrun -v 2>&1 | head -1
pebble-python -c 'import PIL; print(PIL.__version__)'
```

`pebble sdk list` should show `4.33.1 (active)` without any install step.
