# Guide — AI-Era Mock Interview

This is the **candidate-facing** guide. The agent-facing rules live in `SKILL.md`; this file
tells **you** how to drive a session and what to type.

---

## 1. What this simulates

The "AI-era interview" from
`~/yt-summaries/my-interview-experience-for-principal-engineer-interviews-in-ai-era.md`:
you are handed a realistic, buggy Java/Maven codebase plus a symptom-driven JIRA ticket,
you fix it using an AI assistant, and you are graded on **how you direct the AI** — not on
typing code by hand.

The twist: the assistant you prompt and the interviewer who grades you are the **same
agent**. There is no separate "Copilot" tool.

---

## 2. The key mental model: you prompt the same AI that grades you

- A plain message goes to the **Interviewer** (probing, discussion, system design).
- A message starting with `>ai:` goes to the **Copilot** (the coding assistant).
- A message starting with `>hint:` asks the **Interviewer** for a nudge.
- The Copilot behaves like a real assistant: it does **exactly** what your prompt says.
  A vague prompt yields vague/generic output; a precise prompt yields a usable patch.
  It will **not** warn you that your approach is wrong or point at the bug.
- Every `>ai:` prompt is logged verbatim. At the end, the Interviewer scores those prompts
  against the ideal prompt stored in the scenario's hidden `rubric.md`.

So the loop is: **you direct an AI → that same AI assesses how well you directed it.**

---

## 3. Prerequisites

The toolchain is installed via `home-manager switch` in `~/dotfiles` (JDK + Maven).
Verify:

```bash
java -version   # OpenJDK 21+
mvn -version    # Apache Maven 3.9+
```

The first `mvn` run in a session downloads dependencies, so it can be slow; later runs are
fast. If Maven is unavailable or offline, `run-tests.sh` falls back to a dependency-free
`javac`/`java` harness.

---

## 4. Starting a session

Work in a **fresh, empty directory** — the whole session is created there and can be
deleted afterwards.

```bash
mkdir -p ~/interviews/$(date +%F)-rate-limit && cd "$_"
```

Then, in opencode, just ask (natural language — there is no literal slash command to load a
skill):

> start an ai-era mock interview

You can also name specifics up front:

> start an ai-era mock interview on concurrency, architect difficulty, with 2 system design questions

The agent will:
1. Check the directory is empty.
2. Ask a few setup questions (topic, difficulty, rounds, SD branching, curated/generated).
3. Materialize or generate the buggy `codebase/` and write `TICKET.md`.
4. Verify the baseline test fails (so the scenario is actually solvable).
5. Commit the baseline and hand you the ticket.

---

## 5. Command cheat-sheet

| You type | Routed to | What happens |
|---|---|---|
| `why does the counter reset?` (plain) | **Interviewer** | discussion / probing; no code written |
| `I think the bug is a fixed window` (plain) | Interviewer | records your reasoning in the transcript |
| `>ai: <your prompt>` | **Copilot** | generates code exactly as prompted; logged to `prompt-log.md` |
| `>hint:` | **Interviewer** | smallest useful nudge (never the root cause); logged; **costs points** |
| `ask me a system design question` | Interviewer | starts the SD branching phase |
| `run the tests` | Interviewer | runs `run-tests.sh` |
| `end the interview` | Interviewer | debrief → `evaluation.md` + progress line |

Notes:
- Use the markers exactly as `>ai:` and `>hint:` (lowercase, no space before the colon).
- Think out loud in plain messages — the Interviewer values visible reasoning.
- Hints are a safety valve, not a shortcut: **each `>hint:` deducts 2 points** from your
  code-fix score. Use them sparingly.

---

## 6. A worked mini-example

**Weak prompt**

> `>ai: fix the rate limiter`

The Copilot produces a generic rewrite with no knowledge of the symptom or the intended
algorithm — it may even keep the fixed-window logic. The Interviewer notes: no file, no
symptom, no algorithm, no guardrails, no verification.

**Strong prompt**

> `>ai: In codebase/src/main/java/com/example/ratelimit/RateLimiter.java, allow() buckets
> requests by now / windowMillis (fixed window), so a burst split across a window boundary
> is counted as 2+2 instead of 4 in a rolling 1000ms. Reimplement it as a sliding window
> using InMemoryStore.events(key): evict timestamps older than now - windowMillis, reject if
> the remaining count is >= maxRequests, otherwise record now and allow. Keep the
> constructor and the Clock injection unchanged, and make it thread-safe.`

The Copilot returns a usable sliding-window patch that compiles and passes the checks. The
Interviewer scores this highly on context, domain keywords, and guardrails.

The difference between the two is exactly what the interview measures.

---

## 7. How you're graded

**Prompt quality — 5 dimensions, 1–5 each (25 total):**

| Dimension | What's checked |
|---|---|
| Context & precision | Did the prompt name the file/function, symptom, and expected behavior? |
| Domain keywords | Correct terminology (sliding window, unique index, idempotency, backoff+jitter, lock ordering, …) |
| Guardrails | Did you constrain the AI (preserve X, don't touch Y, add tests)? |
| Verification | Did you review/test the output and iterate? |
| Delegation discipline | Did you explore and hypothesize before prompting? |

Plus:
- **Code fix** (10) — root cause addressed, minimal, regression-safe. **Minus 2 per `>hint:`** (floor 0).
- **System design** (10) — correctness and tradeoff awareness.
- **Total /45**, reported as `pass` / `borderline` / `fail`.

Outputs:
- `evaluation.md` — full debrief with an **ideal prompt rewrite** and weak-area links.
- `~/interview-sim/history.jsonl` — one progress line per session (the only file written
  outside the session directory).

---

## 8. Session files & cleanup

Everything is created in the directory you launched from:

```
<your dir>/
  codebase/            # the Java/Maven project you fix
  TICKET.md            # the symptom-driven ticket
  prompt-log.md        # every >ai: prompt, timestamped
  transcript.md        # Q&A, think-aloud, SD discussion, hint count
  scratch/             # your notes
  evaluation.md        # the graded debrief
  session-summary.json # machine-readable result
  .session.json        # scenario/difficulty/state
  .git/                # baseline commit, for diffing
```

When you're done reading `evaluation.md`, delete the whole directory:

```bash
rm -rf ~/interviews/2026-10-03-rate-limit
```

---

## 9. Tips for a strong session

- **Explore before prompting.** Read the ticket, open the files, run the tests, form a
  hypothesis. Dumping the ticket into the AI signals zero engineering mindset.
- **Be specific.** Name the file and function, the observed symptom, and the expected
  behavior.
- **Use domain keywords.** "sliding window", "unique index", "idempotency", "backoff with
  jitter", "lock ordering" — this is what separates an engineer from a prompt typist.
- **Add guardrails.** Tell the AI what not to change and what to preserve.
- **Verify.** Run the tests, read the diff, and iterate. Never trust blindly.
- **Think out loud.** The Interviewer can only credit reasoning it can see.
- **Avoid hints** unless truly stuck — they cost points.

---

## 10. Troubleshooting

- **"directory is not empty"** — launch in a fresh directory; the session needs an empty CWD.
- **`java`/`mvn` not found** — run `home-manager switch` in `~/dotfiles` to install the
  toolchain.
- **Maven hangs / offline** — `run-tests.sh` falls back to `javac`/`java`; the checks still
  run.
- **Generated scenario won't verify** — the agent falls back to a curated scenario
  automatically.
- **Want the guide again** — this file is also deployed at
  `~/.config/opencode/skills/ai-era-mock-interview/GUIDE.md`.
