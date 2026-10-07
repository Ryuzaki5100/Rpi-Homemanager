package com.example.catalog;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * In-memory stand-in for a database. Every call to a {@code find*} method counts as one
 * round trip, so callers can be measured for chatty access patterns.
 */
public class FakeDatabase {

    private final Map<String, Product> products = new HashMap<>();
    private final Map<String, List<Review>> reviewsByProduct = new HashMap<>();
    private final AtomicInteger queryCount = new AtomicInteger();

    public void addProduct(Product product) {
        products.put(product.id(), product);
    }

    public void addReview(String productId, Review review) {
        reviewsByProduct.computeIfAbsent(productId, k -> new ArrayList<>()).add(review);
    }

    public List<Product> findAllProducts() {
        queryCount.incrementAndGet();
        return new ArrayList<>(products.values());
    }

    public List<Review> findReviewsByProductId(String productId) {
        queryCount.incrementAndGet();
        return reviewsByProduct.getOrDefault(productId, List.of());
    }

    /** Batch variant: one round trip for many products. */
    public Map<String, List<Review>> findReviewsByProductIds(Collection<String> productIds) {
        queryCount.incrementAndGet();
        Map<String, List<Review>> result = new HashMap<>();
        for (String id : productIds) {
            result.put(id, reviewsByProduct.getOrDefault(id, List.of()));
        }
        return result;
    }

    public int queryCount() {
        return queryCount.get();
    }

    public void resetQueryCount() {
        queryCount.set(0);
    }
}
