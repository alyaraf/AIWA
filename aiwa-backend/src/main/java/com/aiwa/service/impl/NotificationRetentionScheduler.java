package com.aiwa.service.impl;

import com.aiwa.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDateTime;

/**
 * M-8 / AU-10: notifications are deleted after {@code aiwa.notifications.retention-days}
 * (default 180; 0 keeps them forever). The table grew without bound, and the list is
 * read on every home screen refresh.
 */
@Slf4j
@Component
@Profile("!test")
@RequiredArgsConstructor
public class NotificationRetentionScheduler {

    private final NotificationRepository notifications;
    private final RedisLockService redisLockService;

    @Value("${aiwa.notifications.retention-days:${NOTIFICATION_RETENTION_DAYS:180}}")
    private int retentionDays = 180;

    @Scheduled(cron = "0 30 3 * * *") // every night at 03:30
    public void purge() {
        if (retentionDays <= 0) return;
        // Idempotent, so it may run without the lock while Redis is down.
        redisLockService.withLock("notification-retention", Duration.ofMinutes(30), true, this::purgeOld);
    }

    public int purgeOld() {
        int removed = notifications.deleteOlderThan(LocalDateTime.now().minusDays(retentionDays));
        if (removed > 0) log.info("Removed {} notification(s) older than {} days", removed, retentionDays);
        return removed;
    }
}
