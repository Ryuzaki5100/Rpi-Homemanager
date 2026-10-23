# Sub-skill routing

Invoke a sub-skill with the agent's skill tool using the exact name. If the skill tool is unavailable, read `../<name>/SKILL.md` and follow it.

| Situation | Skill | Pass | Expect |
|---|---|---|---|
| SDK/toolchain missing or broken | `pebble-sdk-setup` | OS, current `pebble` output, error | Working `pebble`, active SDK, QEMU, Pillow; verification report |
| New project or metadata change | `pebble-project-scaffold` | name, type, language, platforms, phone needs | `package.json`, `wscript`, dirs, UUID, validation pass |
| Layout/visual/interaction plan | `pebble-ui-design` | request, platform, type, language | `.pebble/design.md` with edge math and interaction map |
| C watchface or watchapp | `pebble-c-dev` | design path, type, platforms, phone needs | Complete `src/c/*.c`; no placeholder |
| Alloy watchface or watchapp | `pebble-alloy-dev` | design path, type, platforms | Complete `src/embeddedjs/main.js` + manifest |
| Phone data/settings | `pebble-phone` | watch message keys, data source, settings schema | `src/pkjs/index.js`, Clay config, message key updates |
| Build/emulator/verify | `pebble-build-test` | project root, type, interaction list | PBW, logs, screenshots, pass/fail per gate |
| Icons/GIF/publish | `pebble-release` | project root, type, platforms, publish intent | Icons, preview GIF, store listing, optional upload |
| Platform facts/docs/samples | `pebble-core` | specific fact or URL | Facts/paths only |

## Invocation prompt template

```text
Use the <skill-name> skill for this Pebble project at <absolute path>.
Project type: <watchface|watchapp>. Language: <C|Alloy>.
Target platforms: <...>. Phone integration: <none|pkjs|clay>.
Design: <path or "not yet">.
Do <specific task> and return <specific artifact>. Do not build/publish unless asked.
```

## Ordering rules

- Never run `pebble-build-test` before `pebble-project-scaffold` and an implementation skill.
- Never run `pebble-phone` before the watch-side message keys exist.
- Never run `pebble-release` before G4/G5/G6 pass.
- Run `pebble-core` on demand; it is not a pipeline phase.
