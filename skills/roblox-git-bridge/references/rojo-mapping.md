---
name: roblox-git-bridge
description: Rojo project mapping rules, file suffixes, sourcemap generation, and how to retrofit an existing place.
---

# Rojo mapping

## Minimum viable project

```json
{
  "name": "<game-slug>",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": { "$className": "ServerScriptService" },
    "ReplicatedStorage": { "$className": "ReplicatedStorage" },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": { "$className": "StarterPlayerScripts" }
    },
    "Workspace": { "$className": "Workspace" }
  }
}
```

Then add children that point at files:

```json
"NoclipBoot": { "$path": "src/server/NoclipBoot.server.luau" }
```

## File suffixes decide the instance class

| Suffix | Class |
|---|---|
| `.server.luau` | `Script` |
| `.client.luau` | `LocalScript` |
| `.luau` | `ModuleScript` |

Use explicit `"$className"` only when a suffix cannot express it.

## Rules that prevent "my script vanished"

1. A file not referenced in `default.project.json` never reaches Studio.
2. Moving or renaming a file requires updating the mapping in the same commit.
3. Two files must never map to the same instance path.
4. Keep `Workspace` children (baseplate, spawn) in the project so a rebuild is
   playable; otherwise a fresh build spawns players into the void.
5. Modules that require siblings must keep their relative layout under the same
   mapped folder.

## Sourcemap (for luau-lsp)

```sh
rojo sourcemap default.project.json --output sourcemap.json
```

`sourcemap.json` is generated and ignored. A language server without it cannot
resolve `require` paths or the instance tree; pass it only when the file exists.

## Retrofit an existing place

1. Save the place to a local file, then `rojo syncback --input <place.rbxlx>` to
   serialise the tree into project files.
2. Review what it produced: syncback can emit files for instances you meant to
   keep only in the place (terrain, decorative models).
3. Decide the split explicitly: scripts in `src/`, geometry in the tracked
   `.rbxlx`. Do not try to track both representations of the same instance.
4. Commit the initial sync as one commit so later diffs are readable.

## Packages

`wally` is unavailable on aarch64-darwin in nixpkgs. If a game needs Luau
packages, pin the prebuilt release inside that repository's `devenv.nix` and
document the version there, or vendor the package under `src/shared/`.
