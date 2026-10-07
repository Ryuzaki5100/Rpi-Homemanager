# Solution — idor-order-access

**Root cause:** `OrderService.getOrder` returns the order fetched by ID without verifying
that `order.userId()` matches `requestingUserId`. This is an **IDOR** (Insecure Direct
Object Reference) / broken object-level authorization: authentication is present but
authorization is missing.

**Fix:** after loading the order, check ownership and deny mismatches.

```java
public Order getOrder(String requestingUserId, String orderId) {
    Order order = repository.findById(orderId)
            .orElseThrow(() -> new IllegalArgumentException("order not found: " + orderId));
    if (!order.userId().equals(requestingUserId)) {
        throw new AccessDeniedException(
                "user " + requestingUserId + " is not allowed to view order " + orderId);
    }
    return order;
}
```

**Why it works:** a non-owner now receives `AccessDeniedException` instead of the order.

**Acceptable alternatives:** filtering the lookup by `userId` in the repository
(`findByIdAndUserId`), which also avoids leaking existence; an authorization interceptor
applied consistently to all resource reads. Returning `null` silently is weaker but
acceptable if the caller maps it to a denial.

**Distractors:** "authentication is enough" (the notes' wrong assumption) and the
not-found path (unrelated to the IDOR).
