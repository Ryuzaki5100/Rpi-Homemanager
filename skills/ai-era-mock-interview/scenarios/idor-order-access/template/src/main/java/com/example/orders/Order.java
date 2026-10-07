package com.example.orders;

public class Order {

    private final String id;
    private final String userId;
    private final String item;

    public Order(String id, String userId, String item) {
        this.id = id;
        this.userId = userId;
        this.item = item;
    }

    public String id() {
        return id;
    }

    public String userId() {
        return userId;
    }

    public String item() {
        return item;
    }
}
