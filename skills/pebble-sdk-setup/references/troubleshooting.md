# Troubleshooting

## `pebble: command not found`
The home-manager profile is not active. Run `home-manager switch --impure --flake ~/dotfiles#$(whoami)` and restart the shell.

## `pebble sdk list` says no SDK installed
The declarative symlinks are missing or broken. Check:
- macOS: `~/Library/Application Support/Pebble SDK/SDKs/current`
- Linux: `~/.pebble-sdk/SDKs/current`
Re-run `home-manager switch`. Do not run `pebble sdk install`.

## `pebble build` says no SDK
Same as above. Verify `SDKs/4.33.1/sdk-core/manifest.json` exists.

## `qemu-pebble` fails with `Library not loaded`
The wrapper is missing `DYLD_LIBRARY_PATH` (macOS) or `LD_LIBRARY_PATH` (Linux). Check `PEBBLE_QEMU_PATH` and the module's wrapper. On macOS, the package also links `libpng16.16.dylib` from Nix.

## Emulator will not boot / stale app / timeout
```bash
pebble kill
pebble wipe
pebble install --emulator emery
```

## `mcrun: missing MODDABLE environment variable`
Run through `pebble build` (the tool sets `MODDABLE`), or set it to `<SDK root>/toolchain/moddable` for a manual test.

## Build succeeds but resources fail
Check that the SDK `node_modules` symlink exists and that `node --version` is the pinned Node 22. webpack 1.x may need `NODE_OPTIONS=--openssl-legacy-provider`.

## Screenshot shows another app
Stale emulator state. `pebble kill && pebble wipe`, reinstall, then screenshot.

## `home-manager switch` cannot see new files
Flakes only see tracked files. `git add` the new skill/package files first.
