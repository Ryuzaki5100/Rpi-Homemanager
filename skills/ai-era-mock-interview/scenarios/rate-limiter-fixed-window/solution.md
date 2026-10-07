# Solution — rate-limiter-fixed-window

**Root cause:** `RateLimiter.allow` uses a **fixed-window** algorithm. It derives a bucket
from `now / windowMillis` and counts per bucket, so a burst split across a window boundary
(e.g. 2 requests at t=900ms and 2 more at t=1050ms) is counted as 2+2 rather than 4 within
a rolling 1000ms window.

**Fix:** replace the per-bucket counter with a **sliding window** over stored event
timestamps, evicting events older than `now - windowMillis` before deciding.

Replace `RateLimiter.allow` with:

```java
public boolean allow(String userId) {
    long now = clock.now();
    String key = "rl:" + userId;
    Deque<Long> events = store.events(key);
    synchronized (events) {
        while (!events.isEmpty() && events.peekFirst() <= now - windowMillis) {
            events.pollFirst();
        }
        if (events.size() >= maxRequests) {
            return false;
        }
        events.addLast(now);
        return true;
    }
}
```

Add the import `java.util.Deque` to `RateLimiter`.

**Why it works:** at t=1050 the window is (50, 1050]; the events at 900 and 1000 are still
inside it, so the count is 2 and the request is rejected. At t=2000 the window (1000, 2000]
evicts all prior events, so traffic resumes.

**Acceptable alternatives:** token-bucket or leaky-bucket implementations that enforce the
same rolling limit; a Lua-scripted atomic sliding window in a real store; storing a sorted
set with per-timestamp entries. Fixed-window is *not* acceptable.

**Distractors:** the store's latency (notes say it is instant), and the `maxRequests`
constant (it is correct at 2).
