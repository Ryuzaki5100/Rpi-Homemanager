# `pkgs/pebble-sdk` package

The package fetches and assembles the official SDK release into the layout `pebble-tool` expects.

## Contents

| Path | Source |
|---|---|
| `sdk-core/` | `https://sdk.repebble.com/releases/4.33.1/sdk-core.tar.gz` |
| `toolchain/` | `toolchain-mac-arm64.tar.gz` (or the matching platform tarball) |
| `.venv` | Nix Python env with `freetype-py`, pypng **0.20220715.0**, `sh`, `packaging`, `setuptools` |
| `node_modules` | Nix-built `webpack` 1.x and SDK resource dependencies |

The toolchain tarball includes `arm-none-eabi`, `moddable`, `moddable-tools`, `bin/qemu-pebble`, and bundled dylibs.

## Platform hashes

- SDK core: same tarball for all platforms.
- Toolchain: one hash per system (`aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`).
- Compute with `nix-prefetch-url --unpack <url>` then `nix hash convert --hash-algo sha256 --to sri <hash>`.

## Node dependencies

- `pkgs/pebble-sdk/node/package.json` mirrors the SDK core's `package.json`.
- `package-lock.json` is committed.
- `buildNpmPackage` uses `nodejs_22` and `NODE_OPTIONS=--openssl-legacy-provider` for webpack 1.x.
- If the lock changes: `nix run nixpkgs#prefetch-npm-deps -- pkgs/pebble-sdk/node/package-lock.json`.

## QEMU

The suite uses `pebble.packages.${system}.pebble-qemu` (Nix-built QEMU), not the
prebuilt `toolchain/bin/qemu-pebble` from the SDK tarball. The module wraps it
as `qemu-pebble` and pins `PEBBLE_QEMU_PATH`. The SDK toolchain is still used
for `arm-none-eabi` and the Moddable tools.

## Updating the SDK

1. Change `version` and the SDK/toolchain hashes.
2. Update `pkgs/pebble-sdk/node/package.json` if the SDK's Node deps changed.
3. Regenerate `package-lock.json` and `npmDepsHash`.
4. `home-manager switch`.
5. Re-run the smoke test.

## Related packages

The suite also packages two support tools because upstream `pebble.nix` is not
currently buildable against this nixpkgs:

- `pkgs/pebble-tool.nix` — builds pebble-tool from the pebble.nix expression,
  with:
  - plain nixpkgs `rsa` upgraded to 4.9.1 (upstream pins a git revision whose
    metadata reports `4.10.dev0`),
  - a patched emulator wait (SDK 4.33.1 does not expose the serial banner on
    the port the tool waits on),
  - a forced modern QEMU command line when version detection fails.
- `pkgs/pypkjs.nix` — pypkjs with the correct `stpyv8` wheel hash for the
  current Python/platform.

The SDK's resource tooling calls `Reader.asRGBA8()`, which newer pypng releases
removed, so `pkgs/pebble-sdk` pins pypng to `0.20220715.0`. pebble-tool's waf
wrapper also clears `PYTHONPATH` when invoking waf so the SDK's pinned pypng is
not shadowed by pebble-tool's own dependencies.

`modules/common/pebble.nix` wraps `pebble` to put pypkjs and pebble-tool's
Python dependencies on `PYTHONPATH`, so `sys.executable -m pypkjs` and
`-m websockify` work in the emulator.
