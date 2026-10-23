---
name: pebble-project-scaffold
description: Creates or repairs a Pebble project skeleton and metadata for a C or Alloy watchface/watchapp, including package.json, UUID, target platforms, wscript, resource directories, PebbleKit JS/Clay hooks, and pre-build validation. Use after the app type and language are chosen, or when package.json/build metadata is missing or invalid.
---

# pebble-project-scaffold

Produce a correct, buildable Pebble project skeleton. The implementation skills fill in behavior; this skill owns metadata and structure.

## Step 0 — Read the scaffolding guide first (mandatory)
`read <base-dir>/GUIDE.md` before creating files. Use `references/project-types.md`, `references/package-json.md`, and `references/resources.md` as needed.

## Core rules (always apply)
1. **Face vs app changes behavior**: `watchapp.watchface` is `true` for faces, `false` for apps.
2. **Alloy only for emery/gabbro** and requires `"projectType": "moddable"`.
3. **`pebble.sdkVersion` is always `"3"`** even though the SDK is 4.x.
4. **Every project needs a fresh UUID**; never reuse a sample's UUID.
5. **`messageKeys` must list every key** used by C, PKJS, and Clay.
6. **Clay needs `"capabilities": ["configurable"]`**; location needs `["location"]`.
7. **Use the stock wscript**; do not invent build logic.
8. **Validate before implementation** with `scripts/validate_project.py`.
9. **Do not overwrite an existing project** without explicit confirmation.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Choose the project shape | `references/project-types.md` | Face/app and C/Alloy decision matrix |
| Fill `package.json` correctly | `references/package-json.md` | Field-by-field metadata rules |
| Add fonts, images, message keys, Clay | `references/resources.md` | Resource and capability wiring |
| Create the skeleton | `scripts/scaffold.py` | Generates package.json, wscript, src dirs |
| Validate the skeleton | `../pebble-core/scripts/validate_project.py` | Structural pre-build checker |
| Copy stock metadata | `../pebble-core/templates/package.json.template` | Canonical package.json |
| Copy stock build script | `../pebble-core/templates/wscript.template` | Stock wscript |

## Workflow
1. Read `GUIDE.md`.
2. Confirm name, display name, author, type, language, platforms, phone needs.
3. Run `scripts/scaffold.py` or write the equivalent files.
4. Add/verify `messageKeys`, `capabilities`, `resources.media`, `src/pkjs/` if phone integration is planned.
5. Run `validate_project.py`; fix every error.
6. Hand off to `pebble-ui-design` and the implementation skill.

## Output
`package.json`, `wscript`, `.gitignore`, `src/c/` or `src/embeddedjs/`, `resources/`, optional `src/pkjs/`, plus a validation report. No app-specific behavior beyond a minimal buildable skeleton.

## Tools
`read`, `write`/`edit`, `bash` (scaffold/validate), `question` (missing names/type).
