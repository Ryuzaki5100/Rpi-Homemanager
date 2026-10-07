package com.example.ratelimit;

/**
 * Allows at most {@code maxRequests} per user within {@code windowMillis}.
 */
public class RateLimiter {

    private final InMemoryStore store;
    private final int maxRequests;
    private final long windowMillis;
    private final Clock clock;

    public RateLimiter(InMemoryStore store, int maxRequests, long windowMillis, Clock clock) {
        this.store = store;
        this.maxRequests = maxRequests;
        this.windowMillis = windowMillis;
        this.clock = clock;
    }

    public boolean allow(String userId) {
        long now = clock.now();
        long bucket = now / windowMillis;
        String key = "rl:" + userId + ":" + bucket;
        long count = store.incrementAndGet(key);
        return count <= maxRequests;
    }
}
