# Rubric — idor-order-access

- **Topic:** security
- **Difficulty:** mid
- **Bug class:** IDOR / missing object-level authorization
- **Key files:** `codebase/src/main/java/com/example/orders/OrderService.java`

## What a strong candidate does

1. Recognizes that authentication ≠ authorization.
2. Names the bug class (IDOR / broken object-level authorization).
3. Adds an ownership check (or filters by owner in the repository).
4. Considers leaking resource existence (deny vs not-found) and applies the check
   consistently.

## Prompt-quality signals

- **Context & precision:** names `OrderService.getOrder`, the `requestingUserId` parameter,
  and the mismatch case.
- **Domain keywords:** "authorization", "IDOR", "ownership check", "object-level authz".
- **Guardrails:** "keep the not-found behavior", "don't change the repository interface"
  (or explicitly asks to add a scoped lookup).
- **Verification:** runs the checks and confirms the non-owner path is denied.
- **Delegation discipline:** inspects the service before prompting.

## Ideal prompt (example)

> `OrderService.getOrder` loads an order by ID but never checks that it belongs to
> `requestingUserId`, so any authenticated user can read any order (IDOR). Add an
> ownership check: after loading, if `order.userId()` does not equal `requestingUserId`,
> throw `AccessDeniedException`. Preserve the existing "order not found" behavior for
> missing IDs and keep the `OrderRepository` interface unchanged.

## Follow-ups (interviewer)

- Related: how would you enforce this consistently across many endpoints (interceptor,
  policy layer)?
- Related: should a forbidden resource return 403 or 404? Tradeoffs (existence leakage).
- Theory (no AI): authentication vs authorization; other OWASP API top-10 issues.
- Unrelated branch: pick a `~/system-design/` topic (e.g. authn/authz at scale, session vs
  token).

## Red flags

- Asserts authentication is sufficient (repeats the ticket's wrong assumption).
- Hard-codes a specific user or order ID.
- Fixes only the single endpoint's caller rather than the service boundary.
