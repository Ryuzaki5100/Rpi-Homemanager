---
name: system-design-tester
description: Generates a system-design test paper from topics in the ~/system-design reference library and writes it as timestamp-matched questions-<timestamp>.md and questions-<timestamp>.epub at the current repository root. Use when the user wants to be quizzed or tested on system-design topics, names a topic markdown file or directory, or asks for an all-rounded cumulative test. Interactively extracts headings from a named file and asks the user which subtopics to be assessed on.
---

# system-design-tester

Generate a test paper (questions only) for selected system-design topics. Answers are produced separately by the `system-design-tutor` skill, which finds this test through the shared timestamp token. **Never write answers into the questions file.**

## Conventions

Resolve these once and reuse them:

- **Repo root** (works in any repo):
  ```bash
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  ```
- **Timestamp token**: `TS="$(date +%Y-%m-%d-%H-%M-%S)"`
- **Output files**: `$REPO_ROOT/questions-$TS.md` and `$REPO_ROOT/questions-$TS.epub`
- **Ledger**: `$REPO_ROOT/.sd-tester/ledger.json`
- **EPUB script**: `~/dotfiles/skills/system-design-tester/scripts/convert-to-epub.sh`
- **Reference library**: `~/system-design/` (`README.md`, topic dirs `00-`..`15-`, `14-PRACTICE-PROBLEMS/`, `15-CASE-STUDIES/`)

All artifacts are flat files at the repo root — never create per-test folders.

## Phase 1 — Mode detection

Determine the assessment mode from the user's request:

- **topic-drill** — one or more specific topics, markdown files, or a directory is named.
- **cumulative** — the user says "all-rounded", "everything I've studied", "cumulative", or "weak areas".

If neither is clear, ask with the `question` tool.

## Phase 2 — Topic selection

### 2a. A markdown file is named
1. `read` the file.
2. Extract every `##` section as a top-level topic and every `###` subsection as a subtopic. Skip purely navigational headings (e.g. "Table of Contents") and empty sections.
3. Present the extracted topics with the `question` tool (`multiple: true`): list subtopics grouped under their `##` parent, plus an **Entire file** option and, when the file lives in a topic directory, an **All files in <directory>** option.
4. If the user picks **Entire file**, assess the whole file. If they pick the directory, treat every `.md` in it as selected.

### 2b. A directory is named
List its `.md` files with `glob`, ask which file(s) to include, then run 2a for each.

### 2c. Only a topic name is given
Resolve it by searching the library (`glob` on filenames, `grep` on headings), show the matches, and confirm the selection with the user.

### 2d. Cumulative
1. Read `$REPO_ROOT/.sd-tester/ledger.json`. If it does not exist, tell the user there is no history and fall back to 2a–2c.
2. Present studied topics grouped by section with `last_tested` and the latest score.
3. Offer presets with the `question` tool: **Weak** (`weak: true`), **Stale** (not tested in >14 days), **By section**, **Everything**.

Record the chosen set as `selected_topics`, where each entry is `file#heading` (or just `file` for a whole file).

## Phase 3 — Test configuration

Ask with the `question` tool on every run:

1. **Difficulty** — junior / mid / architect / senior-architect.
2. **Question count** — 5 / 10 / 15 / 20 / custom.
3. **Type mix** — allocate counts across: MCQ (rapid recall), short-answer, estimation, tradeoff justification, scenario/"what breaks", full design problem. Offer a **Balanced** preset.
4. **Time limit** — 30 / 45 / 60 / 90 minutes or none.
5. **Open-book or closed-book** — changes the instructions wording.

Store as `difficulty`, `count`, `type_mix`, `time_limit`, `open_book`.

## Phase 4 — Read sources

Read every selected source file fully in parallel with `read`. Extract concepts, definitions, tables, formulas, tradeoffs, and "Think About It" prompts. When a full design problem is requested, also read `~/system-design/14-PRACTICE-PROBLEMS/00-index.md` and 2–3 relevant case studies from `15-CASE-STUDIES/` for format and realism.

## Phase 5 — Generate `questions-$TS.md`

Use this structure (include only the sections present in `type_mix`):

```markdown
# System Design Test — <scope summary>
_Generated <human date> • <difficulty> • <count> questions • <time limit> • <open/closed book>_

## Instructions
[open/closed-book rules, time limit, marks distribution, expected depth for the chosen difficulty]

## Section A — Rapid Recall (MCQ) — <marks>
1. <question>
   - A) ...
   - B) ...
   - C) ...
   - D) ...
   <marks>

## Section B — Short Answer
## Section C — Estimation
## Section D — Tradeoff Justification
## Section E — Scenario / What Breaks
## Section F — Full System Design

## Answer Sheet
<blank numbered lines matching every question>

<!-- SOURCE-MAP
Q1: 04-CACHING/01-caching-fundamentals.md#1.2 Cache Hierarchy
Q2: ...
-->
```

Rules:
- Scale numbers and depth by difficulty exactly as in the table below.
- The full design problem must include functional and non-functional requirements and a short evaluation-rubric prompt.
- The `SOURCE-MAP` HTML comment maps every question to `file#heading`. The tutor reads it from the `.md`; do not rely on it surviving EPUB conversion (the ledger stores a copy as backup).
- Do not include any answers or hints in the paper.

### Difficulty parameter reference

| Parameter | Junior | Mid | Architect | Senior Architect |
|---|---|---|---|---|
| Users | 10K | 1M | 100M | 1B+ |
| Peak QPS | 100 | 10K | 1M | 10M+ |
| Components | 3-5 | 5-8 | 8-12 | 12+ |
| Tradeoff depth | Basic | Moderate | Deep | Expert |
| Failure scenarios | 2-3 | 4-5 | 6-8 | 8+ |
| Consistency | Eventual | Tunable | Strong + eventual | Multi-model |
| Estimation detail | Order of magnitude | Back-of-envelope | Detailed + sensitivity | Multi-dimensional |

## Phase 6 — Output

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TS="$(date +%Y-%m-%d-%H-%M-%S)"
mkdir -p "$REPO_ROOT/.sd-tester"
# write "$REPO_ROOT/questions-$TS.md"
~/dotfiles/skills/system-design-tester/scripts/convert-to-epub.sh \
  "$REPO_ROOT/questions-$TS.md" "$REPO_ROOT/questions-$TS.epub" \
  "System Design Test — $TS"
```

Then ensure the repo-root `.gitignore` contains the generated-artifact block (create it if absent, append if missing):

```gitignore
# system-design-tester artifacts
/questions-*
/answers-*
/.sd-tester/
```

## Phase 7 — Update the ledger

Create or merge `$REPO_ROOT/.sd-tester/ledger.json`:

```json
{
  "version": 1,
  "topics": {
    "<file>#<heading>": {
      "section": "<dir>",
      "heading": "<heading>",
      "first_studied": "<YYYY-MM-DD>",
      "times_tested": 1,
      "last_tested": "<YYYY-MM-DD>",
      "scores": [],
      "weak": false
    }
  },
  "tests": [
    {
      "questions": "questions-<ts>.md",
      "answers": null,
      "topics": ["..."],
      "source_map": {"Q1": "file#heading"},
      "difficulty": "mid",
      "created": "<ts>",
      "result": null
    }
  ]
}
```

- Increment `times_tested` and set `last_tested` for every selected topic.
- Append the test entry with its `source_map`.
- If the ledger is corrupt, back it up to `ledger.json.bak` and start fresh.

## Phase 8 — Report

Tell the user: the repo root, the `questions-<ts>.md` and `.epub` paths, the topics covered, difficulty/count/time, and to run the `system-design-tutor` skill on this file to generate answers or get graded.

## Error handling

- No topics selected → exit cleanly.
- A referenced library file is missing → continue with the available sources and log a warning.
- `pandoc` missing → keep the `.md`, report the install hint printed by the script.
- Ledger corrupt → back it up and start fresh.

## Tools reference

- `question` — user prompts (mode, topics, config, presets)
- `glob` — directory/file and library scanning
- `read` — reading source markdown (use parallel calls)
- `write` — creating `questions-<ts>.md` and the ledger
- `edit` — appending to `.gitignore` / merging the ledger
- `bash` — repo-root/timestamp resolution and EPUB conversion
