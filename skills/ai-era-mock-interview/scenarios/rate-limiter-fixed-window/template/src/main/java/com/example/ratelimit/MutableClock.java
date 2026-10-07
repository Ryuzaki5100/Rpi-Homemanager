package com.example.ratelimit;

/** A clock whose value can be advanced by tests. */
public class MutableClock implements Clock {
    private long now;

    public MutableClock(long start) {
        this.now = start;
    }

    public void set(long value) {
        this.now = value;
    }

    @Override
    public long now() {
        return now;
    }
}
