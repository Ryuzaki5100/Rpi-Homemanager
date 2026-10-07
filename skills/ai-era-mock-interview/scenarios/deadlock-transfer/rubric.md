# Rubric — deadlock-transfer

- **Topic:** concurrency
- **Difficulty:** architect
- **Bug class:** deadlock via inconsistent lock ordering
- **Key files:** `codebase/src/main/java/com/example/bank/TransferService.java`

## What a strong candidate does

1. Reproduces or reasons about the interleaving: T1 holds A waits for B, T2 holds B waits
   for A.
2. Names the bug precisely — lock-ordering deadlock (not "slow DB" or "the sleep").
3. Fixes it with a canonical lock order (by account id) or a bounded `tryLock`.
4. Keeps the operation atomic and explains why no cycle can form afterward.

## Prompt-quality signals

- **Context & precision:** names `TransferService.transfer` and the opposite-direction case.
- **Domain keywords:** "lock ordering", "deadlock", "canonical order", "tryLock", "cycle".
- **Guardrails:** "keep per-account balance atomicity", "don't change the Account API".
- **Verification:** runs the concurrent checks and reasons about the timeout.
- **Delegation discipline:** forms the lock-cycle hypothesis before prompting.

## Ideal prompt (example)

> `TransferService.transfer` deadlocks when two transfers between the same accounts run in
> opposite directions: it locks `from` then `to`, so two threads can each hold one lock and
> wait for the other. Fix it by acquiring locks in a consistent order — e.g. order the two
> accounts by `id()` and always lock the lower id first — while keeping the debit/credit
> atomic. Do not change the `Account` API.

## Follow-ups (interviewer)

- Theory (no AI): name the four Coffman conditions for deadlock.
- Theory (no AI): types of deadlock (single-resource, multi-resource) and how to detect
  them (`ThreadMXBean.findDeadlockedThreads`).
- Write a minimal code snippet that deadlocks — without AI.
- Related: optimistic vs pessimistic locking; what changes in a distributed setting where
  the accounts are separate services?
- Unrelated branch: pick a `~/system-design/` topic (e.g. distributed transactions).

## Red flags

- Blames the `sleep` or "database slowness" without naming lock ordering.
- Removes locking entirely, breaking atomicity.
- Cannot explain the cycle or why ordering fixes it.
