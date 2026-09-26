package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class RedisLockService {

    private final RedisRuntimeService redis;

    public boolean withLock(String lockName, Duration ttl, Runnable work) {
        String key = "lock:" + lockName;
        String owner = UUID.randomUUID().toString();
        try {
            if (!redis.setIfAbsent(key, owner, ttl)) {
                return false;
            }
        } catch (RuntimeException ex) {
            log.warn("Redis lock unavailable for {} — running without distributed lock: {}", lockName, ex.getMessage());
            work.run();
            return true;
        }
        try {
            work.run();
            return true;
        } finally {
            try {
                redis.get(key)
                        .filter(owner::equals)
                        .ifPresent(ignored -> redis.delete(key));
            } catch (RuntimeException ex) {
                log.warn("Redis lock cleanup failed for {}: {}", lockName, ex.getMessage());
            }
        }
    }
}
