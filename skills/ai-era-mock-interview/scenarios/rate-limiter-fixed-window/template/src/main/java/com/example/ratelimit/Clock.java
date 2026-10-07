package com.example.ratelimit;

/** Injectable time source so rate-limit windows can be tested deterministically. */
public interface Clock {
    long now();
}
