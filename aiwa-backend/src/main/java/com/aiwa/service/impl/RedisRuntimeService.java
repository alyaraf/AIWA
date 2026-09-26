package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.stream.MapRecord;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
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

    public long increment(String key, Duration ttl) {
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, ttl);
        }
        return count != null ? count : 0L;
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

    public void publishStream(String stream, Map<String, String> payload) {
        try {
            redis.opsForStream().add(MapRecord.create(stream, payload));
        } catch (RuntimeException ex) {
            log.warn("Redis stream publish failed for {}: {}", stream, ex.getMessage());
        }
    }
}
