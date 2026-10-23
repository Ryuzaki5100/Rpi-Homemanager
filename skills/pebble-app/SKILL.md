---
name: pebble-app
description: Orchestrates building a complete Pebble watchface or watchapp, from requirements and design through C or Alloy implementation, optional PebbleKit JS/Clay phone integration, emulator testing with visual verification, and PBW delivery. Use when the user asks to create, build, modify, test, or ship a Pebble watchface/watchapp, or says "make me a watchface/app for Pebble".
---

# pebble-app

Router and quality gate for the Pebble skill suite. It classifies the request, calls the right sub-skills in order, and refuses to deliver an unbuilt or unverified app.

## Step 0 — Read the orchestration guide first (mandatory)
`read <base-dir>/GUIDE.md` before doing anything else. Then use `references/routing.md` for the exact sub-skill invocation prompts and `references/contracts.md` for the artifacts each phase must produce.

## Core rules (always apply)
1. **Classify before writing code**: watchface vs watchapp, C vs Alloy, target platform, phone integration. Record the decision in `.pebble/state.json`.
2. **Emery is the default target** (200x228). Alloy is only valid for emery/gabbro.
3. **Use the sub-skills** for depth: SDK setup, scaffold, design, C, Alloy, phone, build/test, release. Do not reimplement their guidance in this file.
4. **Never write API calls from memory**; use `pebble-core/references/live-docs.md`.
5. **Watchfaces have no buttons**; use `MINUTE_UNIT` unless the user explicitly asks for seconds.
6. **PKJS/Clay is phone-side JavaScript bundled in the PBW**, not a separate installed app. Native Android/iOS companions are out of scope.
7. **Build and visually verify before delivery**: `pebble build` → install on emery → screenshot → view the image → pass the checklist. A PBW without a verified screenshot is not done.
8. **Iterate until the gates pass**; do not deliver with cropping, crashes, missing interactions, or broken settings.
9. **Publish only with explicit user consent.**
10. **Keep project artifacts** in `.pebble/` and never delete the user's source.

## Files & routing
| When you need to… | Read | Purpose |
|---|---|---|
| Understand the full pipeline and gates | `GUIDE.md` | Phase-by-phase orchestration |
| Choose which sub-skill to call and what to pass | `references/routing.md` | Invocation prompts and hand-offs |
| Check required artifacts per phase | `references/contracts.md` | State/design/test/report schemas |
| Start the project state file | `templates/state.json` | Machine-readable phase state |
| Report the final result | `templates/final-report.md` | Delivery report shape |
| Look up platform facts or docs | `../pebble-core/SKILL.md` | Shared reference library |

## Workflow
1. **Preflight** → load `pebble-sdk-setup`; verify `pebble`, SDK, QEMU, Pillow. If missing, fix the environment before continuing.
2. **Intake and classify** → ask only what is unclear; write `.pebble/state.json`.
3. **Scaffold** → `pebble-project-scaffold` creates metadata, build script, resources, UUID.
4. **Design** → `pebble-ui-design` writes `.pebble/design.md` with layout math and interaction map.
5. **Implement watch side** → `pebble-c-dev` or `pebble-alloy-dev`.
6. **Implement phone side** → `pebble-phone` only if data, location, web APIs, or settings are needed.
7. **Build and test** → `pebble-build-test`; iterate until build, screenshot QA, interaction QA, and phone QA pass.
8. **Release assets** → `pebble-release` for icons, preview GIF, store metadata; publish only if asked.
9. **Deliver** → report PBW path, verified screenshot(s), GIF, install commands, limitations.

## Output location
- Project: the user's chosen directory (or CWD).
- State/design/verification: `<project>/.pebble/`.
- PBW: `<project>/build/<name>.pbw`.
- Screenshots/GIF/icons: project root, named `screenshot_emery.png`, `preview_emery.gif`, `icon_80x80.png`, `icon_144x144.png`.
- Final report: use `templates/final-report.md`.

## Tools
`skill` (preferred sub-skill invocation), `read` (fallback `../<skill>/SKILL.md`), `write`/`edit`, `bash` (build/emulator), `question` (intake), `glob`/`grep` (inspect project).
