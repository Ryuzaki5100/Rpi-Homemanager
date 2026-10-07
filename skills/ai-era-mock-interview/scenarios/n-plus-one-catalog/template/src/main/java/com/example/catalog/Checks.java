package com.example.catalog;

import java.util.List;

/** Dependency-free acceptance checks; also runnable via {@code java com.example.catalog.Checks}. */
public final class Checks {

    private static final int PRODUCT_COUNT = 50;

    private Checks() {
    }

    public static void runAll() {
        listingIsCorrectAndNotChatty();
        System.out.println("All catalog checks passed.");
    }

    private static void listingIsCorrectAndNotChatty() {
        FakeDatabase db = new FakeDatabase();
        for (int i = 0; i < PRODUCT_COUNT; i++) {
            String id = "p" + i;
            db.addProduct(new Product(id, "Product " + i));
            db.addReview(id, new Review("r" + i, 5));
        }

        CatalogService service = new CatalogService(db);
        db.resetQueryCount();
        List<ProductView> views = service.listProductsWithReviewCount();

        check(views.size() == PRODUCT_COUNT, "expected all " + PRODUCT_COUNT + " products");
        check(views.get(0).reviewCount() == 1, "expected each product to report 1 review");
        check(db.queryCount() <= 2,
                "expected at most 2 database round trips, but made " + db.queryCount()
                        + " (looks like a per-product query)");
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
