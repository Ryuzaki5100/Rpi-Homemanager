---
name: pebble-core
description: Shared Pebble reference library for watchface and watchapp skills. Load when another Pebble skill points here for platform dimensions, memory limits, battery constraints, live API documentation URLs, sample/tutorial examples, canonical build metadata, or project validation. Not a standalone build workflow.
---

# pebble-core

Canonical Pebble facts and reusable assets. Other Pebble skills route here instead of duplicating platform data, docs links, or stock build files.

## Core rules (always apply)
1. **Emery is the default target**: Pebble Time 2, 200x228 rectangular, 64-color.
2. **Alloy supports only emery and gabbro**. Any older platform requires C.
3. **Never write API calls from memory** — fetch the live page from `references/live-docs.md` before using a signature, enum, or platform note.
4. **Use `layer_get_bounds()` / `bounds.size`**, never hardcoded screen sizes, in generated code.
5. **Battery first**: watchfaces use `MINUTE_UNIT` unless the user explicitly asks for seconds; stop timers when idle.
6. **No floating point in C**: use `sin_lookup` / `cos_lookup` fixed-point helpers.
7. **Watchfaces have no buttons**; button input belongs to watchapps.
8. **Alloy project metadata** requires `"projectType": "moddable"`; C projects must not set it.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Look up screen size, shape, colors, memory, platform capabilities | `references/platforms.md` | Full platform matrix and limits |
| Find the live documentation page for an API or guide | `references/live-docs.md` | Markdown URLs for developer.repebble.com |
| Study a working example or tutorial | `references/samples.md` | Index of samples/tutorials and what each demonstrates |
| Check battery, memory, or cross-platform rules | `references/constraints.md` | Non-negotiable SDK constraints |
| Start a project's build metadata | `templates/package.json.template` | Canonical `package.json` shape |
| Start a project's build script | `templates/wscript.template` | Stock Pebble wscript |
| Generate an app UUID | `scripts/generate_uuid.py` | UUID helper |
| Validate project metadata and sources | `scripts/validate_project.py` | Pre-build structural checker |
| Validate the Pebble skill suite itself | `scripts/validate_skills.py` | Frontmatter/routing/orphan checker |

## Workflow
This skill has no pipeline of its own. Read only the file the calling skill names, return the relevant facts or copied asset path, and stop.

## Output
Facts, paths, or copied template/script content. Do not create a project or install anything from this skill.

## Tools
`read` (references/templates), `bash` (run UUID/validation helpers), `webfetch`/`websearch` (live docs when the URL index is insufficient).
