# Rubric — n-plus-one-catalog

- **Topic:** data / performance
- **Difficulty:** mid
- **Bug class:** N+1 query
- **Key files:** `codebase/src/main/java/com/example/catalog/CatalogService.java`

## What a strong candidate does

1. Recognizes the per-product query loop as an N+1 pattern.
2. Uses the batch API (`findReviewsByProductIds`) or an equivalent single query.
3. Keeps output correct and ordering unchanged.
4. Explains the round-trip count before/after.

## Prompt-quality signals

- **Context & precision:** names `listProductsWithReviewCount` and the per-product call.
- **Domain keywords:** "N+1", "batch fetch", "single round trip", "join/aggregate".
- **Guardrails:** "keep the returned `ProductView` fields and ordering", "don't change
  `FakeDatabase` semantics".
- **Verification:** runs the checks and inspects the query counter.
- **Delegation discipline:** reads the loop before prompting.

## Ideal prompt (example)

> `CatalogService.listProductsWithReviewCount` calls `findReviewsByProductId` once per
> product (N+1). Replace the loop with a single batched call to
> `FakeDatabase.findReviewsByProductIds(ids)`, build the `ProductView` list from the
> returned map, and keep the same ordering and fields. Do not change the database API.

## Follow-ups (interviewer)

- Related: how would you detect N+1 in production (query logging, APM, query counts)?
- Related: when is caching review counts appropriate, and how do you invalidate it?
- Theory (no AI): index design for the batch lookup; offset vs cursor pagination for the
  listing page itself.
- Unrelated branch: pick a `~/system-design/` topic (e.g. caching, read replicas).

## Red flags

- Concludes "scale the database" without addressing the N+1.
- Breaks ordering or drops products.
- Introduces a query per product in a different form.
