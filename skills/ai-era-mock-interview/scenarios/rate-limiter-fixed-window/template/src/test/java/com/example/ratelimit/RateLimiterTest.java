package com.example.ratelimit;

import org.junit.jupiter.api.Test;

class RateLimiterTest {

    @Test
    void rateLimitIsEnforcedAsASlidingWindow() {
        Checks.runAll();
    }
}
