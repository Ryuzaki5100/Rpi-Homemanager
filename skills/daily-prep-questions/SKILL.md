---
name: daily-prep-questions
description: Generate a balanced daily interview-prep session — 3 LeetCode problems, 2 system design questions, 1 behavioral question, 1 SQL problem, and 1 LLD problem — tracked, deterministic, no repeats. Use when the user asks for today's prep set, wants to start a study session, or needs daily interview practice.
---

# daily-prep-questions skill

Deliver 8 interview-prep questions each day, drawn from curated banks covering LeetCode, system design, behavioral, SQL, and low-level design. Progress is tracked; no question repeats within a full cycle.

---

## How it works

Run the daily selector script and present its output to the user.

```bash
cd ~/dotfiles/skills/daily-prep-questions && python3 scripts/generate-daily.py --date <YYYY-MM-DD>
```

If no `--date` is given, the script defaults to today's date.  
Results are **deterministic**: the same date always yields the same questions.

---

## What to show the user

After running the script, present the output as-is, then add these action items:

1. **LeetCode** — encourage the user to solve 2 mediums + 1 hard; log results in `~/Documents/01-leetcode-tracker/lc-tracker.csv`.
2. **System Design** — prompt the user to sketch a full HLD on paper: requirements, API, data model, deep dives, tradeoffs. Check `~/Documents/03-system-design/01-16-problems/` for reference.
3. **Behavioral** — ask the user to answer out loud using STAR (Situation, Task, Action, Result). Reference `~/Documents/02-behavioral-stories/behavioral-stories-prep.md`.
4. **SQL** — ask the user to write the query + EXPLAIN ANALYZE. See `~/Documents/04-sql/00-sql-basics-to-advanced.md` or `03-query-optimization-master.md` for help.
5. **LLD** — ask the user to draw a class diagram + write core Java. Reference `~/Documents/05-lld-java/` for patterns and prior solutions.

---

## End-of-day flow

When the user reports back (same session or later):

1. Ask for today's solve status (completed / stuck / skipped for each).
2. If LC problems were solved, prompt them to update `lc-tracker.csv` via:
   ```bash
   python3 ~/Documents/01-leetcode-tracker/lc-tracker-update.py add
   ```
3. If they report stuck/struggle, suggest a revisit date (3 days for stuck, 1 week for slow).

---

## Resetting the cycle

Once every ~6 weeks (or whenever all banks are exhausted and the user wants to re-see every problem):

```bash
python3 scripts/generate-daily.py --reset
```

This clears progress; the pointer resets to the start of every bank.

---

## Weakness detection (weekly summary)

After 5 sessions, tally the user's results:

- LC patterns with >2 "stuck" → flag for extra review
- SD topics with >2 skipped → suggest reading the relevant section of the SD guide
- SQL topics with stuck → suggest the optimization master file

Tell the user their weak patterns explicitly and suggest 2-3 extra problems that week.

---

## Reference files (absolute paths)

| What | Path |
|---|---|
| LC tracker CSV + updater | `~/Documents/01-leetcode-tracker/lc-tracker.csv` |
| LC tracker guide | `~/Documents/01-leetcode-tracker/lc-tracker-guide.md` |
| LC tracker CLI (add) | `~/Documents/01-leetcode-tracker/lc-tracker-update.py` |
| SD master topics | `~/Documents/03-system-design/00-master-topics.md` |
| SD problems | `~/Documents/03-system-design/01-16-problems/` |
| Behavioral prep | `~/Documents/02-behavioral-stories/behavioral-stories-prep.md` |
| SQL tutorial | `~/Documents/04-sql/00-sql-basics-to-advanced.md` |
| SQL optimization | `~/Documents/04-sql/03-query-optimization-master.md` |
| LLD patterns + solutions | `~/Documents/05-lld-java/` |
| Data banks (source) | `~/dotfiles/skills/daily-prep-questions/data/` |