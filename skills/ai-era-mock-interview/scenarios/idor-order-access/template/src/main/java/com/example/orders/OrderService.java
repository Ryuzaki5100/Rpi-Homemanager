package com.example.orders;

/** Serves order details to the authenticated user identified by {@code requestingUserId}. */
public class OrderService {

    private final OrderRepository repository;

    public OrderService(OrderRepository repository) {
        this.repository = repository;
    }

    public Order getOrder(String requestingUserId, String orderId) {
        return repository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("order not found: " + orderId));
    }
}
