# Rubric — rate-limiter-fixed-window

- **Topic:** concurrency / api-correctness
- **Difficulty:** mid
- **Bug class:** fixed-window vs sliding-window rate limiting
- **Key files:** `codebase/src/main/java/com/example/ratelimit/RateLimiter.java`

## What a strong candidate does

1. Reads the ticket, then explores the codebase before prompting the AI.
2. Identifies that `allow` buckets by `now / windowMillis` (fixed window) and explains the
   boundary-burst flaw with a concrete timeline.
3. Prompts the AI with context: the file, the symptom, the algorithm to use ("sliding
   window"), and a constraint ("keep the `Clock` and store interfaces, do not change the
   constructor").
4. Reviews the generated diff, runs the tests, and confirms the boundary case.

## Prompt-quality signals

- **Context & precision:** names `RateLimiter.allow`, the 2/1000ms config, the boundary case.
- **Domain keywords:** "sliding window", "rolling window", "evict events older than window".
- **Guardrails:** "preserve the `InMemoryStore` API", "keep the `Clock` injection".
- **Verification:** runs `mvn test` / the checks and inspects the diff.
- **Delegation discipline:** forms the fixed-vs-sliding hypothesis before prompting.

## Ideal prompt (example)

> In `RateLimiter.allow`, the limiter uses a fixed-window counter keyed by
> `now / windowMillis`, which allows bursts at window boundaries. Reimplement it as a
> sliding window using the timestamps available from `InMemoryStore.events(key)`: evict
> events older than `now - windowMillis`, reject if the remaining count is >= maxRequests,
> otherwise record `now` and allow. Keep the constructor and the `Clock` injection
> unchanged, and make it thread-safe.

## Follow-ups (interviewer)

- Related: how would this work across horizontally scaled servers? (distributed rate
  limiting, Redis, atomicity).
- Related: what happens if the shared store is down — fallback strategy and cascading
  failure risk.
- Theory (no AI): compare fixed window, sliding window, and token bucket; memory vs
  accuracy tradeoffs.
- Unrelated branch: pick a `~/system-design/` topic (e.g. caching, queueing).

## Red flags

- Dumps the ticket into the AI without reading `RateLimiter`.
- Accepts a "fix" that merely shrinks the window or raises `maxRequests`.
- Cannot explain the boundary-burst timeline.
