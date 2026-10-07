# Solution — n-plus-one-catalog

**Root cause:** `CatalogService.listProductsWithReviewCount` issues one
`findReviewsByProductId` call **per product** after loading all products — the classic
**N+1 query** problem. Round trips grow linearly with catalog size.

**Fix:** fetch all review counts in a single batched call using the existing
`FakeDatabase.findReviewsByProductIds` method.

```java
public List<ProductView> listProductsWithReviewCount() {
    List<Product> products = db.findAllProducts();
    List<String> ids = products.stream().map(Product::id).toList();
    Map<String, List<Review>> reviewsByProduct = db.findReviewsByProductIds(ids);

    List<ProductView> result = new ArrayList<>();
    for (Product product : products) {
        List<Review> reviews = reviewsByProduct.getOrDefault(product.id(), List.of());
        result.add(new ProductView(product.id(), product.name(), reviews.size()));
    }
    return result;
}
```

Add the import `java.util.Map`.

**Why it works:** now there are exactly two round trips — one for products, one for the
batched review lookup — independent of catalog size.

**Acceptable alternatives:** a single JOIN/aggregate query returning products with counts;
caching review counts if staleness is acceptable. Raising the DB size is **not** a fix
(it hides the N+1).

**Distractors:** the ticket's "undersized database" lead; the per-product lookup is
individually efficient, which masks the aggregate cost.
