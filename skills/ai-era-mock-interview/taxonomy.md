# Bug-class taxonomy

Production-code bug classes for scenarios. Each scenario is a **symptom-driven ticket**: the ticket states the observed symptom, the root cause is hidden, and 1–2 plausible distractors are present so the candidate must actually investigate. Difficulty scales codebase size, distractor count, and follow-up depth.

Curated scenarios live in `scenarios/<name>/`. Generated scenarios may target any row below.

## data — persistence & data correctness
- N+1 query / chatty ORM access
- Missing or misused index; slow query
- Broken transaction boundary (partial commit, self-invocation, missing rollback)
- Lost update (optimistic vs pessimistic locking)
- Offset pagination instability (rows shift between pages)
- Connection-pool exhaustion
- Batch insert / unbounded `IN` clause
- Money as `double` instead of `BigDecimal`; rounding errors
- Timezone / date-boundary bug

## caching
- Cache stampede (thundering herd on expiry)
- Stale cache / wrong invalidation
- Wrong eviction policy / unbounded cache growth
- Cache-aside read-your-writes bug

## concurrency
- Race condition on shared mutable state
- Deadlock (inconsistent lock ordering)
- Unsafe publication / missing `volatile`
- `ThreadLocal` leak / memory leak
- Thread-pool misconfiguration (unbounded queue, no rejection policy)
- Lock contention / coarse-grained locking

## reliability
- Retry storm / no exponential backoff + jitter
- Missing client timeout
- Missing circuit breaker → cascading failure
- Resource leak (unclosed streams, connections, executors)
- Swallowed exception / lost stack trace
- Non-idempotent consumer under at-least-once delivery
- Poison message blocking a queue

## security
- SQL injection via string concatenation
- IDOR / broken object-level authorization
- PII or secrets written to logs
- Weak randomness / predictable token
- Path traversal on file upload/download
- SSRF on user-supplied URL

## api-correctness
- Missing input validation / mass assignment
- Unstable sort / non-deterministic ordering
- JSON infinite recursion or over-serialization
- Illegal state-machine transition allowed
- Backward-incompatible API change / missing versioning
- Feature-flag / config precedence bug

## performance
- Unbounded collection growth
- O(n²) work in a hot loop
- Excessive allocation / GC pressure
- Redundant recomputation (missing memoization)

## observability
- Missing correlation / trace IDs across calls
- Metrics cardinality explosion (unbounded labels)
- Log-level misuse (INFO in a hot loop, no context)
- Health check that doesn't reflect dependencies

---

## Difficulty mapping

| Aspect | junior | mid | architect | senior-architect |
|---|---|---|---|---|
| Files in codebase | 4–6 | 6–10 | 10–16 | 14–20 |
| Layers | 1 (service) | 2 (service + repo) | 3 (controller/service/repo) | 3–4 + config/async |
| Distractor bugs | 0 | 1 | 1–2 | 2–3 |
| Root-cause subtlety | obvious | moderate | subtle | cross-cutting |
| Follow-up depth | basic | moderate | deep | expert |
| SD branching count | 1 | 2 | 3 | 4 |

## Ticket framing rules

- State the **symptom** (what a user/monitor observed), not the cause.
- Include a realistic reporter, priority, and 2–4 acceptance criteria.
- Add at least one plausible-but-wrong lead (e.g. "we already added a check" that is insufficient).
- Never name the bug class in the ticket.
