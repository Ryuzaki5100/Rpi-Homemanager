# [API-1042] Rate limit not holding during traffic spikes

**Type:** Bug
**Priority:** High
**Reporter:** Platform SRE
**Component:** api-gateway / rate-limiter
**Environment:** prod — v3.4.1

## Description

Each user is configured for a limit of **2 requests per minute**, but during traffic
spikes we see up to ~30 distinct requests per user reaching the database within a short
window. The limiter appears to work in steady state but lets bursts through when traffic
arrives around the edge of the window.

## Steps to reproduce

1. Send 2 requests for a user, wait ~0.9s, send another.
2. Immediately after the window boundary, send 2 more requests.
3. Observe that more than 2 requests are accepted within a rolling one-minute span.

## Expected behavior

No more than 2 requests per user are accepted within any rolling 60-second window.

## Actual behavior

Bursts of up to ~4 requests per user are accepted within a few seconds around the window
boundary, causing the database spike.

## Acceptance criteria

- [ ] At most 2 requests per user are accepted in any rolling window.
- [ ] A request blocked at the limit is allowed again once the window has slid past it.
- [ ] Existing single-user steady-state behavior is unchanged.

## Notes / investigation so far

The limiter uses the shared store's atomic counter. A teammate suggested the issue is the
store being too slow, but the counter returns instantly in load tests.
