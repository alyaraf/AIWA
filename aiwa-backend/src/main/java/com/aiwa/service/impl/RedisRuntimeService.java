package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class RedisRuntimeService {

    private final StringRedisTemplate redis;

    public void set(String key, String value, Duration ttl) {
        redis.opsForValue().set(key, value, ttl);
    }

    public Optional<String> get(String key) {
        return Optional.ofNullable(redis.opsForValue().get(key));
    }

    public boolean exists(String key) {
        Boolean found = redis.hasKey(key);
        return Boolean.TRUE.equals(found);
    }

    public void delete(String key) {
        redis.delete(key);
    }

    /** INCR and set the expiry in one step: a failure between the two used to leave a counter that never expired (R2-16). */
    private static final RedisScript<Long> INCR_WITH_TTL = RedisScript.of(
            "local c = redis.call('INCR', KEYS[1]) if c == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end return c",
            Long.class);

    /** Deletes the key only while it still holds the expected value (DR-016, DR-025). */
    private static final RedisScript<Long> COMPARE_AND_DELETE = RedisScript.of(
            "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end",
            Long.class);

    public long increment(String key, Duration ttl) {
        Long count = redis.execute(INCR_WITH_TTL, List.of(key), String.valueOf(ttl.toMillis()));
        return count != null ? count : 0L;
    }

    /** True when the key held {@code expected} and this call removed it; only one caller can win. */
    public boolean compareAndDelete(String key, String expected) {
        Long removed = redis.execute(COMPARE_AND_DELETE, List.of(key), expected);
        return removed != null && removed > 0;
    }

    public boolean setIfAbsent(String key, String value, Duration ttl) {
        Boolean locked = redis.opsForValue().setIfAbsent(key, value, ttl);
        return Boolean.TRUE.equals(locked);
    }

    public void setLongList(String key, List<Long> values, Duration ttl) {
        try {
            String payload = String.join(",", values.stream().map(String::valueOf).toList());
            set(key, payload, ttl);
        } catch (RuntimeException ex) {
            log.warn("Redis list cache write failed for {}: {}", key, ex.getMessage());
        }
    }

    public Optional<List<Long>> getLongList(String key) {
        try {
            return get(key)
                    .filter(value -> !value.isBlank())
                    .map(value -> Arrays.stream(value.split(","))
                            .filter(part -> !part.isBlank())
                            .map(Long::valueOf)
                            .toList());
        } catch (RuntimeException ex) {
            log.warn("Redis list cache read failed for {}: {}", key, ex.getMessage());
            return Optional.empty();
        }
    }
}
