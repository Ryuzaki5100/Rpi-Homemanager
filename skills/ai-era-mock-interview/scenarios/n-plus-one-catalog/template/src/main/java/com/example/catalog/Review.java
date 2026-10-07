package com.example.catalog;

public class Review {

    private final String id;
    private final int rating;

    public Review(String id, int rating) {
        this.id = id;
        this.rating = rating;
    }

    public String id() {
        return id;
    }

    public int rating() {
        return rating;
    }
}
