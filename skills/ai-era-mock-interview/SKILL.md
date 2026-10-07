---
name: ai-era-mock-interview
description: Runs an AI-era mock interview in the current working directory. Scaffolds a realistic buggy Java/Maven codebase under ./codebase plus a symptom-driven JIRA ticket, has the agent play BOTH interviewer and the Copilot the user prompts (prompts logged via '>ai:', nudges requested via '>hint:'), interleaves system-design and theory follow-ups from ~/system-design, and grades the user on prompt quality, the resulting code diff, and the design discussion. Use when the user asks for a mock interview, wants to practice AI-assisted debugging on a Java codebase, mentions a JIRA-ticket-driven interview, or wants to be judged on the quality of their AI prompts.
---

# ai-era-mock-interview

Recreate the "AI-era interview" from `~/yt-summaries/my-interview-experience-for-principal-engineer-interviews-in-ai-era.md`: the candidate fixes a real, symptom-driven bug in a Java codebase using an AI assistant, and is judged on **how they direct the AI**, not on typing code by hand.

Everything for a session lives in the **current working directory** (the invocation directory) so the whole session can be deleted at the end. The only external write is one progress line appended to `~/interview-sim/history.jsonl`.

---

## Roles (dual-role, single session)

You play **two** roles and must switch cleanly:

- **Interviewer** (default): presents the ticket and codebase, probes reasoning, asks theory + system-design follow-ups, grades at the end. Also answers `>hint:` requests with the smallest useful nudge (never the root cause).
- **Copilot** (the AI assistant): triggered only by user prompts prefixed `>ai:`. You respond *as a coding assistant* — produce exactly what the prompt asks, nothing more. **Never volunteer hints about the root cause, never mention the bug, never add unsolicited suggestions.** The quality of your output must faithfully mirror the quality of the prompt (a vague prompt yields vague/generic output). This is the core mechanic that makes the prompt-quality assessment meaningful.

---

## Interaction protocol

- A plain message from the user → addressed to the **interviewer** (answers, thinking out loud, clarifying questions).
- A message starting with `>ai:` → addressed to the **Copilot**. Append the raw prompt to `prompt-log.md` with a timestamp before responding.
- A message starting with `>hint:` → a nudge request to the **Interviewer**. Give the smallest useful hint toward the next step (never the root cause, never the solution). Append it to `transcript.md` and increment the session's hint count; each hint costs assessment points.
- The user may run commands themselves. You may also run read-only inspection for them when asked.

Logging format appended to `prompt-log.md`:

```markdown
## Prompt #<n> — <YYYY-MM-DD HH:MM:SS>
> <the exact prompt text>
```

---

## Session workspace (the invocation directory)

```
<CWD>/
  codebase/                 # the Java/Maven project the user fixes (pom.xml, src/main/…, src/test/…)
  TICKET.md                 # symptom-driven JIRA ticket (root cause NOT stated)
  prompt-log.md             # every >ai: prompt, timestamped
  transcript.md             # interviewer Q&A, thinking-out-loud notes, SD discussion
  scratch/                  # user's own notes/sketches
  evaluation.md             # final graded debrief
  session-summary.json      # machine-readable result
  .session.json             # state: scenario, topic, difficulty, source, round
  .git/                     # baseline commit of the buggy code, for diffing
```

`solution.md` and `rubric.md` live under `~/dotfiles/skills/ai-era-mock-interview/scenarios/<name>/` and are **never copied into the workspace**. Read them as the interviewer only.

---

## Phase 0 — Setup

1. **Safety gate.** Confirm the CWD is empty (or contains only `.git`). If it contains anything else, stop and tell the user to invoke the skill in a fresh directory. Then run:
   ```bash
   ~/dotfiles/skills/ai-era-mock-interview/scripts/init-session.sh
   ```
2. **Collect configuration** with the `question` tool:
   - **Topic** — any category from `taxonomy.md` (data, caching, concurrency, reliability, security, api-correctness, performance, observability) or "surprise me".
   - **Difficulty** — junior / mid / architect / senior-architect.
   - **Rounds** — 1 (recommended) or more.
   - **System-design branching** — on/off, and how many SD questions.
   - **Scenario source** — curated, generated, or either.
3. **Select or generate the scenario.**
   - *Curated*: list `~/dotfiles/skills/ai-era-mock-interview/scenarios/*/`; pick one whose `rubric.md` topic matches. Copy its `template/` contents into `<CWD>/codebase/` and read its `ticket.md` to author `<CWD>/TICKET.md` (paraphrase, keep the symptom-only framing).
   - *Generated*: synthesize a fresh, realistic, multi-layer codebase (controller/service/repository/config/DTO, not toy code) for the chosen topic + difficulty, plus a hidden `solution.md` and `rubric.md` written to the skill's `scenarios/generated-<slug>/` folder.
4. **Self-verify before presenting** (mandatory for generated; sanity-check for curated):
   ```bash
   ~/dotfiles/skills/ai-era-mock-interview/scripts/run-tests.sh
   ```
   The baseline must **compile** and the intended test must **fail**. Apply the hidden solution in a scratch copy and confirm it **passes**. If verification fails, regenerate. Do not present an unsolvable or already-passing scenario.
5. **Write session state** to `.session.json` (see `templates/session-state.schema.json`), create `prompt-log.md`, `transcript.md`, and `scratch/`, then commit the baseline:
   ```bash
   cd <CWD> && git add -A && git commit -q -m "baseline: buggy codebase + ticket"
   ```

---

## Phase 1 — Brief

- Present `TICKET.md` to the user. Describe the codebase layout at a high level (packages, entry points) **without revealing the bug**.
- State the rules: they may explore, run tests, use the assistant via `>ai:`, and request nudges via `>hint:` (each hint costs points); every prompt and hint is logged and graded.
- Invite clarifying questions (answered as the interviewer, without giving away the cause).

---

## Phase 2 — Solve

- The user explores and thinks out loud. Respond as the interviewer: ask "why", "what did you check", "what did you rule out".
- When they send `>ai: …`, log it and respond as the Copilot (faithful to prompt quality only).
- Probe along the way — but do not solve it for them. If they dump the ticket straight into the AI without exploring, let the assistant produce a plausible-but-unverified result (do not correct it), and note the pattern for grading.

---

## Phase 3 — Verify

- Have the user run `~/dotfiles/skills/ai-era-mock-interview/scripts/run-tests.sh` (or `mvn -q test` in `codebase/`).
- Ask them to explain *why* it now passes/fails, what they changed, and whether they reviewed the AI's output. Note whether they verified rather than trusted blindly.

---

## Phase 4 — Theory + system-design branching

After the code round, run follow-ups scaled by difficulty:

1. **Related** follow-ups that extend the bug's domain (e.g. fixed→sliding window → distributed rate limiting → Redis outage → cascading failure → fallback policy). Prefer theory questions where the AI is **not** allowed (types of deadlock, index internals, transaction isolation, idempotency).
2. **Unrelated** branch: pick a topic from `~/system-design/` (e.g. a case study in `14-PRACTICE-PROBLEMS/` or `15-CASE-STUDIES/`, or a `##` heading from a topic file). Present it as a discussion; there is no single right answer — grade awareness of tradeoffs and consequences.
3. Record the Q&A in `transcript.md`.

Use the difficulty table (same as `system-design-tester`):

| Parameter | Junior | Mid | Architect | Senior Architect |
|---|---|---|---|---|
| Scale | 10K | 1M | 100M | 1B+ |
| Peak QPS | 100 | 10K | 1M | 10M+ |
| Components | 3-5 | 5-8 | 8-12 | 12+ |
| Tradeoff depth | Basic | Moderate | Deep | Expert |
| Failure scenarios | 2-3 | 4-5 | 6-8 | 8+ |

---

## Phase 5 — Debrief

Grade the session and write `evaluation.md` (template: `templates/evaluation.template.md`).

**Prompt-quality rubric** — score each dimension 1–5 (total /25):

| Dimension | What you're checking |
|---|---|
| Context & precision | Did the prompt name the file/function, the observed symptom, and the expected behavior? |
| Domain keywords | Correct terminology used (sliding window, unique index, idempotency, backoff+jitter, lock ordering, cursor pagination, etc.) |
| Guardrails | Did they constrain the AI (preserve behavior X, don't touch Y, add tests, keep the interface)? |
| Verification | Did they review/test the AI output and iterate on it? |
| Delegation discipline | Did they explore and form a hypothesis *before* prompting, instead of dumping the ticket? |

Also include:
- **Diff quality** — did the fix address the root cause, stay minimal, and not introduce regressions?
- **Hints used** — count from `transcript.md`; deduct **2 points per hint** from the code-fix score (floor 0).
- **System-design answers** — correctness and tradeoff awareness.
- **Ideal prompt rewrite** — show what a top-tier prompt for this ticket would have looked like.
- **Weak areas + resources** — link relevant `~/system-design/` or `~/Documents/05-lld-java/` files.

Write `session-summary.json` and append one progress line:

```json
{"ts":"<ISO8601>","dir":"<abs CWD>","scenario":"<name>","topic":"<category>","difficulty":"<tier>","source":"curated|generated","prompt_score":18,"prompt_max":25,"code_score":8,"code_max":10,"sd_score":7,"sd_max":10,"hints_used":0,"overall":"pass|borderline|fail","weak_areas":["guardrails","verification"]}
```

```bash
mkdir -p ~/interview-sim && echo '<the json line>' >> ~/interview-sim/history.jsonl
```

---

## Phase 6 — Report

- Summarize the score and 2–3 concrete improvements.
- Remind the user that the entire session (codebase, logs, analysis, evaluation) is self-contained in the current directory and can be deleted now.

---

## Error handling

- **Non-empty CWD** → stop; instruct the user to run in a fresh directory.
- **Java/Maven missing** → `run-tests.sh` falls back to `javac`/`java` when possible; if neither exists, tell the user to run `home-manager switch` in `~/dotfiles/` to install `jdk` + `maven`.
- **`.m2` cold / offline** → first `mvn` run needs network; fallback harness runs without JUnit if needed.
- **Generated scenario fails self-verification twice** → fall back to a curated scenario and tell the user.

## Tools reference

- `question` — config, scenario choice, difficulty
- `bash` — `init-session.sh`, `run-tests.sh`, `git`, history append
- `read` — scenario `ticket.md` / `solution.md` / `rubric.md`, taxonomy, `~/system-design/` sources
- `write` / `edit` — TICKET.md, prompt-log.md, transcript.md, .session.json, evaluation.md, generated codebases
- `glob` / `grep` — locate curated scenarios and system-design topics
