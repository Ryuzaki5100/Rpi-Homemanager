# [CAT-455] Product listing page is slow and hammers the database

**Type:** Bug (performance)
**Priority:** High
**Reporter:** Catalog team
**Component:** catalog / listing-service
**Environment:** prod — v1.9.0

## Description

The product listing page that shows each product with its review count has become slow as
the catalog grew. The database CPU spikes whenever the page is loaded, and the number of
queries per page request scales with the number of products rather than staying constant.

## Steps to reproduce

1. Load the product listing endpoint with N products in the catalog.
2. Observe N+1 database round trips (one for the products, then one per product).
3. Latency and DB load grow roughly linearly with the number of products.

## Expected behavior

The listing is built with a small, bounded number of database round trips, independent of
the number of products.

## Actual behavior

One query per product is issued to fetch review counts, causing the DB load.

## Acceptance criteria

- [ ] The listing returns the correct products with correct review counts.
- [ ] The number of database round trips stays constant (<= 2) regardless of catalog size.
- [ ] Output ordering and contents are unchanged.

## Notes / investigation so far

The review lookup per product is straightforward and fast on its own, so the team suspects
the database server is simply undersized.
