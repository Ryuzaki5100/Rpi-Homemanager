# [ORD-778] Customers can view other customers' orders by changing the order ID

**Type:** Bug (security)
**Priority:** Critical
**Reporter:** Security review
**Component:** orders / order-service
**Environment:** prod — v5.0.2

## Description

A penetration test found that an authenticated user can retrieve **any** order by
requesting a different order ID, regardless of who owns it. The endpoint requires a valid
session, so the tester was logged in as one user and successfully fetched another user's
order detail.

## Steps to reproduce

1. Log in as user A and note an order ID belonging to user B.
2. Request `GET /orders/{id}` for user B's order while authenticated as user A.
3. The response returns user B's order data.

## Expected behavior

A user can only retrieve orders they own; access to another user's order is denied.

## Actual behavior

Any authenticated user can read any order by guessing or observing the order ID.

## Acceptance criteria

- [ ] A user can read their own order.
- [ ] A user receives an authorization error when requesting another user's order.
- [ ] A missing order still returns a not-found error.

## Notes / investigation so far

The endpoint is behind authentication, so the team assumed ownership was implied by the
session. The service looks up the order purely by ID.
