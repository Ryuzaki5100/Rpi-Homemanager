# [PAY-2210] Transfer service hangs under concurrent load

**Type:** Bug
**Priority:** Critical
**Reporter:** Payments on-call
**Component:** payments / transfer-service
**Environment:** prod — v2.1.0

## Description

Under concurrent load, the transfer service periodically stops making progress: worker
threads pile up and the service becomes unresponsive until it is restarted. It happens
most often when many transfers occur between the same pair of accounts in both
directions at roughly the same time.

## Steps to reproduce

1. Start two transfers between the same two accounts, in opposite directions, at the
   same time.
2. Observe that both requests hang and never return.
3. A thread dump shows two threads each holding one lock and waiting for the other.

## Expected behavior

Concurrent transfers complete without hanging, regardless of direction.

## Actual behavior

Two concurrent opposite transfers deadlock; both threads block forever.

## Acceptance criteria

- [ ] Concurrent opposite transfers between the same accounts complete within a bounded time.
- [ ] No thread ever waits indefinitely on an account lock.
- [ ] Transfers still update balances atomically.

## Notes / investigation so far

We already guard each account with a lock so balances stay consistent, so the accounts
themselves should be safe. Load only seems to matter when both directions run together.
