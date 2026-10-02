---
name: system-design-tutor
description: Generates an answer key for a system-design test produced by the system-design-tester skill, writing timestamp-matched answers-<timestamp>.md and answers-<timestamp>.epub at the repository root, grades a submitted attempt against the rubric, and answers free-form "why is the answer to Qn X" questions with justification and reasoning drawn from the source markdown. Use when the user references a questions-<timestamp> file, asks for answers/solutions, wants their test graded, or asks to explain a specific test question.
---

# system-design-tutor

Companion to `system-design-tester`. It reads a `questions-<timestamp>.md` paper, produces `answers-<timestamp>.md` (plus EPUB), grades attempts, and tutors the reasoning behind any question. **Never modify the questions file.**

## Conventions

- **Repo root**: `REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`
- **Questions file**: `$REPO_ROOT/questions-<TS>.md`
- **Answers file**: `$REPO_ROOT/answers-<TS>.md` (and `.epub`) — same `<TS>` token as the questions file.
- **Ledger**: `$REPO_ROOT/.sd-tester/ledger.json`
- **EPUB script**: `~/dotfiles/skills/system-design-tutor/scripts/convert-to-epub.sh`
- **Reference library**: `~/system-design/`

## Phase 1 — Locate the test

1. If the user named a file or path, use it.
2. Otherwise list `$REPO_ROOT/questions-*.md` (newest first) and pick the most recent, or ask which one.
3. Extract the timestamp token `TS` from the filename: `questions-<TS>.md` → `<TS>`.
4. The matching answer path is `answers-<TS>.md`. **This timestamp pairing is the sole mapping mechanism** — if an `answers-<TS>.md` already exists, read it rather than overwrite, unless the user asks to regenerate.
5. Read the questions file. Extract the embedded `SOURCE-MAP` HTML comment. If absent, fall back to `tests[].source_map` in the ledger for the matching `questions` entry.

## Phase 2 — Load source context

Read, in parallel, every source markdown file referenced by the source map (strip the `#heading` when opening the file). Also read the ledger entry for this test if present. These sources are the ground truth for the answer key.

## Phase 3 — Generate `answers-$TS.md` + EPUB

For each question, write:

- **Model answer** — depth appropriate to the test's stated difficulty.
- **Must-mention key points** — the checklist a strong answer hits.
- **Rubric** — point allocation summing to the question's marks.
- **Common mistakes** — likely traps and misconceptions.
- **Source** — `file#heading` plus a one-line rationale.

Type-specific handling:
- **MCQ** — the correct option, why it is correct, and why each distractor is wrong.
- **Short answer / tradeoff** — expected reasoning and the explicit tradeoff axis.
- **Estimation** — show the worked calculation (assumptions → throughput/storage/latency → result).
- **Scenario / what breaks** — failure mode, detection signal, mitigation, user impact, recovery.
- **Full system design** — architect-level solution reusing the structure from `hld-problems-generator`: estimation, high-level architecture, data model, component deep dives, tradeoff table, failure scenarios, scaling evolution.

Header format:

```markdown
# Answer Key — System Design Test (<TS>)
_Companion to questions-<TS>.md • <difficulty> • <count> questions_

## Q1 — <short label>  [<marks>]
**Model answer:** ...
**Key points:** ...
**Rubric:** ...
**Common mistakes:** ...
**Source:** `file#heading` — <rationale>
```

Then convert:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
~/dotfiles/skills/system-design-tutor/scripts/convert-to-epub.sh \
  "$REPO_ROOT/answers-$TS.md" "$REPO_ROOT/answers-$TS.epub" \
  "Answer Key — System Design Test ($TS)" "System Design Tutor"
```

## Phase 4 — Update the ledger

In `$REPO_ROOT/.sd-tester/ledger.json`:
- Set the matching test entry's `answers` to `answers-<TS>.md`.
- Record that the answer key was generated.

## Phase 5 — Grading (on request)

When the user submits an attempt (pasted in chat or a file path):
1. Match each answer to its question.
2. Score against the rubric; award partial credit for key points.
3. Report per-question marks, a total, and targeted feedback (what was missed, what was strong).
4. Append the result to the ledger:
   - Push `{ "questions": "questions-<ts>.md", "earned": <n>, "total": <m> }` into each topic's `scores`.
   - Set `weak: true` for topics scoring below 60%.
   - Set the test entry's `result` to the total.
5. Recommend the exact source sections to review for each weak topic.

## Phase 6 — Reasoning tutor (on request)

When the user asks "why is Q3's answer X?", "explain Q5", or similar:
1. Read `answers-<TS>.md` for the question and its rubric.
2. Read the cited source markdown (and the wider file) for the underlying concept.
3. Respond with the justification, the reasoning chain, the relevant tradeoffs, and cite `file#heading`.
4. If the user's intuition conflicts with the key, explain precisely where it diverges.
5. Optionally Socratic-quiz ledger-flagged weak topics with new follow-up questions.

## Error handling

- No `questions-*` file found → tell the user to generate one with `system-design-tester`.
- Source file missing → answer from the questions paper alone and flag the gap.
- `pandoc` missing → keep the `.md`, report the install hint.
- Existing answer file and no regeneration requested → read it instead of overwriting.

## Tools reference

- `read` — questions file, source markdown, ledger, submitted attempts (parallel calls)
- `glob` — locating `questions-*` / `answers-*` at the repo root
- `write` — creating `answers-<ts>.md`
- `edit` — merging the ledger
- `bash` — repo-root resolution and EPUB conversion
- `question` — disambiguating which test to use
