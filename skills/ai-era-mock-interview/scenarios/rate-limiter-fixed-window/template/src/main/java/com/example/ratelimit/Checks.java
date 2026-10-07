package com.example.ratelimit;

/** Dependency-free acceptance checks; also runnable via {@code java com.example.ratelimit.Checks}. */
public final class Checks {

    private Checks() {
    }

    public static void runAll() {
        enforcesLimitWithinSlidingWindow();
        allowsAfterWindowSlides();
        System.out.println("All rate-limiter checks passed.");
    }

    /** Requests 900ms and 1000ms in, then 1050ms in, must be blocked (3 within 1000ms). */
    private static void enforcesLimitWithinSlidingWindow() {
        MutableClock clock = new MutableClock(0);
        RateLimiter limiter = new RateLimiter(new InMemoryStore(), 2, 1000, clock);

        check(limiter.allow("u1"), "first request should be allowed");
        clock.set(900);
        check(limiter.allow("u1"), "second request should be allowed");
        clock.set(1000);
        check(limiter.allow("u1"), "third request at t=1000 should be allowed (2 in window)");
        clock.set(1050);
        check(!limiter.allow("u1"), "fourth request at t=1050 must be blocked (3 in last 1000ms)");
    }

    /** Once the window has fully slid past all prior requests, traffic is allowed again. */
    private static void allowsAfterWindowSlides() {
        MutableClock clock = new MutableClock(0);
        RateLimiter limiter = new RateLimiter(new InMemoryStore(), 2, 1000, clock);

        check(limiter.allow("u2"), "first request allowed");
        clock.set(100);
        check(limiter.allow("u2"), "second request allowed");
        clock.set(2000);
        check(limiter.allow("u2"), "window has fully slid; request allowed again");
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
