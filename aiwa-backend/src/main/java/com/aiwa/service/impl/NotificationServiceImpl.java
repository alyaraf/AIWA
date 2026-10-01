package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.Notification;
import com.aiwa.entity.User;
import com.aiwa.enums.Language;
import com.aiwa.enums.NotificationType;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.NotificationRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.PushNotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl {

    private final NotificationRepository notificationRepo;
    private final UserRepository userRepo;
    private final PushNotificationService pushService;
    private final PushDeviceService pushDevices;

    /**
     * Where device pushes run. Defaults to the calling thread (unit tests); the
     * application wires a small pool (PushExecutorConfig) so an FCM round-trip
     * never holds a request thread or a database transaction open.
     */
    private java.util.concurrent.Executor pushExecutor = Runnable::run;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPushExecutor(@org.springframework.beans.factory.annotation.Qualifier("pushExecutor")
                         java.util.concurrent.Executor pushExecutor) {
        this.pushExecutor = pushExecutor;
    }

    /** Runs the push after the surrounding transaction commits (never for a rolled-back change). */
    private void afterCommit(Runnable push) {
        Runnable guarded = () -> {
            try {
                push.run();
            } catch (RuntimeException e) {
                log.warn("Push delivery failed: {}", e.getMessage());
            }
        };
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            pushExecutor.execute(guarded);
                        }
                    });
        } else {
            pushExecutor.execute(guarded);
        }
    }

    /** Internal: create and persist a notification */
    @Transactional
    public void send(Long userId, NotificationType type,
                     String titleEn, String titleAr,
                     String bodyEn, String bodyAr,
                     Long relatedBookingId, Long relatedProviderId) {

        User user = userRepo.findById(userId).orElse(null);
        if (user == null) return;

        // Columns are 255 (titles) / 1000 (bodies). Bodies can embed user text
        // (reasons, names); an over-long value used to fail the insert — and with
        // it the booking transaction that triggered the notification.
        titleEn = clip(titleEn, 255);
        titleAr = clip(titleAr, 255);
        bodyEn = clip(bodyEn, 1000);
        bodyAr = clip(bodyAr, 1000);

        Notification n = Notification.builder()
                .user(user)
                .type(type)
                .titleEn(titleEn).titleAr(titleAr)
                .bodyEn(bodyEn).bodyAr(bodyAr)
                .relatedBookingId(relatedBookingId)
                .relatedProviderId(relatedProviderId)
                .read(false)
                .build();

        Notification saved = notificationRepo.save(n);

        // In-app inbox always records the notification (above); the real-time push
        // channel respects the user's preferences (mute, push toggle, quiet hours)
        // — except safety alerts, which must reach support and the user regardless.
        boolean urgent = type == NotificationType.SAFETY_ALERT;
        if (urgent || pushAllowed(user)) {
            // (A Redis stream copy of every notification used to be written here;
            // nothing read it and it was never trimmed, R2-16.)
            var devices = pushDevices.devicesOf(userId);
            if (!devices.isEmpty()) {
                boolean arabic = user.getPreferredLanguage() == Language.AR;
                String title = arabic && titleAr != null ? titleAr : titleEn;
                String body = arabic && bodyAr != null ? bodyAr : bodyEn;
                Map<String, String> data = Map.of(
                        "notificationId", String.valueOf(saved.getId()),
                        "type", type.name(),
                        "relatedBookingId", relatedBookingId != null ? String.valueOf(relatedBookingId) : "",
                        "relatedProviderId", relatedProviderId != null ? String.valueOf(relatedProviderId) : "");
                for (var device : devices) {
                    String token = device.getToken();
                    com.aiwa.enums.DevicePlatform platform = device.getPlatform();
                    afterCommit(() -> pushService.send(token, platform, title, body, data));
                }
            } else {
                log.debug("Push allowed for user {} but no device token is registered — nowhere to deliver it", userId);
            }
        }
    }

    /** Whether a real-time push may be delivered to this user right now. */
    private boolean pushAllowed(User user) {
        if (user.isMuteAll() || !user.isNotifyPush()) return false;
        return !withinQuietHours(user, java.time.LocalTime.now());
    }

    /** Handles same-day (09:00–17:00) and overnight (22:00–07:00) quiet windows. */
    static boolean withinQuietHours(User user, java.time.LocalTime now) {
        java.time.LocalTime start = user.getQuietHoursStart();
        java.time.LocalTime end = user.getQuietHoursEnd();
        if (start == null || end == null || start.equals(end)) return false;
        if (start.isBefore(end)) {
            return !now.isBefore(start) && now.isBefore(end);
        }
        // overnight window wraps past midnight
        return !now.isBefore(start) || now.isBefore(end);
    }

    @Transactional(readOnly = true)
    public Page<ApiResponse.NotificationDto> getMyNotifications(Long userId, Pageable pageable) {
        return notificationRepo.findByUserIdOrderByCreatedAtDesc(userId, pageable)
                .map(this::toDto);
    }

    @Transactional(readOnly = true)
    public long countUnread(Long userId) {
        return notificationRepo.countByUserIdAndReadFalse(userId);
    }

    @Transactional
    public void markAllRead(Long userId) {
        notificationRepo.markAllReadForUser(userId);
    }

    /** BE-11: mark one of the caller's own notifications read (404 for anyone else's). */
    @Transactional
    public ApiResponse.NotificationDto markRead(Long userId, Long notificationId) {
        Notification n = notificationRepo.findByIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Notification", notificationId));
        if (!n.isRead()) {
            n.setRead(true);
            notificationRepo.save(n);
        }
        return toDto(n);
    }

    private static String clip(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max - 1) + "…";
    }

    private ApiResponse.NotificationDto toDto(Notification n) {
        return ApiResponse.NotificationDto.builder()
                .id(n.getId())
                .type(n.getType())
                .titleEn(n.getTitleEn())
                .titleAr(n.getTitleAr())
                .bodyEn(n.getBodyEn())
                .bodyAr(n.getBodyAr())
                .relatedBookingId(n.getRelatedBookingId())
                .relatedProviderId(n.getRelatedProviderId())
                .read(n.isRead())
                .createdAt(n.getCreatedAt())
                .build();
    }
}
