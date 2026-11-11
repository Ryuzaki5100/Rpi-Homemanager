---
name: roblox-git-bridge
description: GitHub Actions for a Roblox project plus Open Cloud publishing with place:write, including what CI cannot do.
---

# CI and publishing

## What CI can and cannot do

| Can | Cannot |
|---|---|
| lint (`selene`) | launch Roblox Studio |
| format check (`stylua --check`) | run playtests or `--task RunScript` (needs a signed-in Studio) |
| build the place (`rojo build`) | verify DataModel behaviour |
| upload the `.rbxlx` as an artifact | publish without an Open Cloud key |
| publish on tag (with a key) | |

Say this plainly instead of promising gameplay CI. Gameplay verification is the
Studio MCP loop on the developer's machine.

## Tool pinning

Prefer one mechanism: either the repository's `devenv.nix` (used locally and by
agents) or `rojo`/`selene`/`stylua` binaries fetched in the workflow. Do not mix,
or CI and local disagree at the worst moment.

The template workflow downloads pinned releases, which keeps the workflow
self-contained for contributors who do not use Nix.

## Publishing

`rojo upload` uses the Open Cloud API:

```sh
rojo upload \
  --api_key "$ROBLOX_API_KEY" \
  --universe_id <universeId> \
  --asset_id <placeId> \
  default.project.json
```

Rules:

- Keep the key in a GitHub secret or the user's environment; never commit it.
- Require a clean working tree so the published build matches a commit.
- Gate on an explicit request (a tag or a manual dispatch), never on every push.
- Grant only the `place:write` scope needed.
- Studio's *Publish to existing experience* is the no-key alternative, but it is
  manual and overwrites the cloud place with the local build.

## Template workflow outline

```yaml
on:
  push: { branches: [main] }
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - install pinned rojo / selene / stylua (curl releases, chmod +x)
      - run: selene src
      - run: stylua --check src
      - run: rojo build default.project.json -o build/game.rbxlx
      - upload-artifact build/game.rbxlx
```

Publish is a separate, tag-triggered job that reuses the built artifact and reads
`secrets.ROBLOX_API_KEY`.

## Reproducing the published place

The tracked `.rbxlx` plus `rojo build` must always reproduce what players see. If
a change exists only in the cloud place, the repository is lying — that is the
failure mode this whole setup exists to prevent.
