package com.aiwa.support;

import com.aiwa.service.impl.RedisRuntimeService;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Map-backed stand-in for {@link RedisRuntimeService} so API-level tests run
 * the real OTP, idempotency, blacklist and rate-limit code paths without a
 * Redis server. TTLs are honoured lazily on read.
 */
public class InMemoryRedisRuntimeService extends RedisRuntimeService {

    private record Entry(String value, Instant expiresAt) {
        boolean expired() {
            return expiresAt != null && Instant.now().isAfter(expiresAt);
        }
    }

    private final Map<String, Entry> store = new ConcurrentHashMap<>();

    public InMemoryRedisRuntimeService() {
        super(null);
    }

    public void clear() {
        store.clear();
    }

    private Entry live(String key) {
        Entry e = store.get(key);
        if (e != null && e.expired()) {
            store.remove(key);
            return null;
        }
        return e;
    }

    @Override
    public void set(String key, String value, Duration ttl) {
        store.put(key, new Entry(value, ttl == null ? null : Instant.now().plus(ttl)));
    }

    @Override
    public Optional<String> get(String key) {
        Entry e = live(key);
        return Optional.ofNullable(e == null ? null : e.value());
    }

    @Override
    public boolean exists(String key) {
        return live(key) != null;
    }

    @Override
    public void delete(String key) {
        store.remove(key);
    }

    @Override
    public synchronized long increment(String key, Duration ttl) {
        Entry e = live(key);
        long next = (e == null ? 0 : Long.parseLong(e.value())) + 1;
        Instant exp = e == null ? (ttl == null ? null : Instant.now().plus(ttl)) : e.expiresAt();
        store.put(key, new Entry(String.valueOf(next), exp));
        return next;
    }

    @Override
    public synchronized boolean setIfAbsent(String key, String value, Duration ttl) {
        if (live(key) != null) return false;
        set(key, value, ttl);
        return true;
    }

    @Override
    public void setLongList(String key, List<Long> values, Duration ttl) {
        set(key, String.join(",", values.stream().map(String::valueOf).toList()), ttl);
    }

    @Override
    public Optional<List<Long>> getLongList(String key) {
        return get(key).filter(v -> !v.isBlank())
                .map(v -> Arrays.stream(v.split(",")).map(Long::valueOf).toList());
    }

    @Override
    public void publishStream(String stream, Map<String, String> payload) {
        // no consumer in tests
    }
}
