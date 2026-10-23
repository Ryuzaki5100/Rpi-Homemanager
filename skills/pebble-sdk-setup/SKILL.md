---
name: pebble-sdk-setup
description: Verifies or repairs the Pebble development environment on this machine using the Nix/home-manager setup in ~/dotfiles, including the Nix-packaged Pebble SDK core, ARM/Moddable toolchain, QEMU emulator, pebble CLI, and Pillow. Use before building Pebble apps, when pebble is missing, when the SDK is not detected, when the emulator will not start, or when installing a PBW on a real watch.
---

# pebble-sdk-setup

Ensure `pebble`, the SDK, QEMU, the ARM/Moddable toolchain, and Pillow are available **from Nix**, then verify the whole flow.

## Step 0 — Read the setup guide first (mandatory)
`read <base-dir>/GUIDE.md` before changing anything. Use `references/nix-home-manager.md` for the exact files/commands and `references/nix-package.md` for how the SDK package is built.

## Core rules (always apply)
1. **This machine is Nix-managed.** Install/repair through `~/dotfiles` + `home-manager switch`; do not use Homebrew, `uv tool install`, or pip for the SDK.
2. **Never run `pebble sdk install`.** The SDK core is a Nix package; `pebble sdk list` must already show `4.33.1 (active)`.
3. **Do not edit `~/dotfiles` blindly.** Inspect `git status` first; preserve unrelated uncommitted changes.
4. **Flakes only see git-tracked files.** New Nix/skill files must be `git add`ed before `home-manager switch`.
5. **Verify after switching**: `pebble --version`, `pebble sdk list`, `qemu-pebble --version`, `pebble-python -c 'import PIL'`.
6. **Emulator hygiene**: if the emulator is wedged, `pebble kill && pebble wipe`, then install again.
7. **Device installs** use `pebble login` + `pebble install --cloudpebble`, or `--phone <ip>` / `--serial`; see the device reference.
8. **Do not install Android/iOS native SDKs.** Phone-side Pebble code is PKJS/Clay inside the PBW.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| See the full verification/repair flow | `GUIDE.md` | Ordered setup and repair procedure |
| Wire the SDK into `~/dotfiles` | `references/nix-home-manager.md` | Flake input, module, symlinks, switch |
| Understand or update the SDK package | `references/nix-package.md` | Package layout, hashes, Python/Node deps |
| Install on a real watch | `references/device-deploy.md` | CloudPebble, LAN, serial, login |
| Diagnose a failure | `references/troubleshooting.md` | Common Nix/SDK/QEMU errors |
| Run a quick health check | `scripts/check-env.sh` | Non-destructive environment report |

## Workflow
1. Read `GUIDE.md`.
2. Run `scripts/check-env.sh`; identify the first failing check.
3. If the failure is Nix/deployment, apply `references/nix-home-manager.md` and run `home-manager switch`.
4. If the failure is SDK/package-specific, use `references/nix-package.md`.
5. Re-run the health check; then run the smoke test in `GUIDE.md` (new project → build → emery install → screenshot).
6. Report versions, active SDK path, and any caveat. Stop before build/test; the caller owns those phases.

## Output
A short environment report: OS, `pebble` version, SDK version/active path, QEMU version, Pillow version, and whether the smoke test passed. No project source changes.

## Tools
`read`, `bash` (health checks, `home-manager switch` with consent), `write`/`edit` (only `~/dotfiles` Nix files when asked), `question` (confirm system changes).
