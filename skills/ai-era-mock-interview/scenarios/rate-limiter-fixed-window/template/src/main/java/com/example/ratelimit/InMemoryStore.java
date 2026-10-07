package com.example.ratelimit;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Minimal stand-in for a shared key-value store (e.g. Redis).
 * Exposes an atomic counter and a per-key event list, mirroring the
 * operations a real store offers.
 */
public class InMemoryStore {

    private final Map<String, AtomicLong> counters = new ConcurrentHashMap<>();
    private final Map<String, Deque<Long>> events = new ConcurrentHashMap<>();

    public long incrementAndGet(String key) {
        return counters.computeIfAbsent(key, k -> new AtomicLong()).incrementAndGet();
    }

    public Deque<Long> events(String key) {
        return events.computeIfAbsent(key, k -> new ArrayDeque<>());
    }
}
