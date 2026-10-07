package com.example.orders;

/** Dependency-free acceptance checks; also runnable via {@code java com.example.orders.Checks}. */
public final class Checks {

    private Checks() {
    }

    public static void runAll() {
        ownerCanReadOwnOrder();
        nonOwnerCannotReadOthersOrder();
        System.out.println("All order-access checks passed.");
    }

    private static void ownerCanReadOwnOrder() {
        OrderRepository repo = new OrderRepository();
        repo.save(new Order("o1", "alice", "book"));
        OrderService service = new OrderService(repo);

        Order order = service.getOrder("alice", "o1");
        check(order != null && "o1".equals(order.id()), "owner must be able to read own order");
    }

    private static void nonOwnerCannotReadOthersOrder() {
        OrderRepository repo = new OrderRepository();
        repo.save(new Order("o1", "alice", "book"));
        OrderService service = new OrderService(repo);

        boolean denied = false;
        try {
            service.getOrder("bob", "o1");
        } catch (AccessDeniedException e) {
            denied = true;
        }
        check(denied, "non-owner must be denied access to another user's order (IDOR)");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    public static void main(String[] args) {
        runAll();
    }
}
