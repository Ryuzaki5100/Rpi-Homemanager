package com.example.catalog;

import java.util.ArrayList;
import java.util.List;

/** Builds the product listing page, including each product's review count. */
public class CatalogService {

    private final FakeDatabase db;

    public CatalogService(FakeDatabase db) {
        this.db = db;
    }

    public List<ProductView> listProductsWithReviewCount() {
        List<Product> products = db.findAllProducts();
        List<ProductView> result = new ArrayList<>();
        for (Product product : products) {
            List<Review> reviews = db.findReviewsByProductId(product.id());
            result.add(new ProductView(product.id(), product.name(), reviews.size()));
        }
        return result;
    }
}
