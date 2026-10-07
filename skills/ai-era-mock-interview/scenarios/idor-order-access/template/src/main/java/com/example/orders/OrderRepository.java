package com.example.orders;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public class OrderRepository {

    private final Map<String, Order> store = new HashMap<>();

    public void save(Order order) {
        store.put(order.id(), order);
    }

    public Optional<Order> findById(String id) {
        return Optional.ofNullable(store.get(id));
    }
}
