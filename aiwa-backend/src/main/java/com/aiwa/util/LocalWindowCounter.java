package com.aiwa.util;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process fixed-window counter: the rate limiters' fallback while Redis is down, so throttling
 * keeps working (per backend instance) instead of failing open. The counts are not shared between
 * instances and are lost on restart, which is acceptable for a degraded mode.
 */
public class LocalWindowCounter {

    /** Entries kept before expired windows are swept; bounds memory under a key-spraying attack. */
    private static final int SWEEP_ABOVE = 10_000;

    private record Window(long expiresAtNanos, long count) {}

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();

    /** Adds one to {@code key}'s count for the current window and returns the new count. */
    public long increment(String key, Duration window) {
        long now = System.nanoTime();
        if (windows.size() > SWEEP_ABOVE) {
            windows.values().removeIf(w -> w.expiresAtNanos() - now <= 0);
        }
        return windows.merge(key, new Window(now + window.toNanos(), 1),
                (old, fresh) -> old.expiresAtNanos() - now <= 0 ? fresh : new Window(old.expiresAtNanos(), old.count() + 1))
                .count();
    }
}
