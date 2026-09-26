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
    private final RedisRuntimeService redis;
    private final PushNotificationService pushService;

    /** Internal: create and persist a notification */
    @Transactional
    public void send(Long userId, NotificationType type,
                     String titleEn, String titleAr,
                     String bodyEn, String bodyAr,
                     Long relatedBookingId, Long relatedProviderId) {

        User user = userRepo.findById(userId).orElse(null);
        if (user == null) return;

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
        // channel respects the user's preferences (mute, push toggle, quiet hours).
        if (pushAllowed(user)) {
            redis.publishStream("stream:notifications", Map.of(
                    "notificationId", String.valueOf(saved.getId()),
                    "userId", String.valueOf(userId),
                    "type", type.name(),
                    "titleEn", titleEn != null ? titleEn : "",
                    "relatedBookingId", relatedBookingId != null ? String.valueOf(relatedBookingId) : "",
                    "relatedProviderId", relatedProviderId != null ? String.valueOf(relatedProviderId) : ""
            ));

            if (user.getPushToken() != null && !user.getPushToken().isBlank()) {
                boolean arabic = user.getPreferredLanguage() == Language.AR;
                String title = arabic && titleAr != null ? titleAr : titleEn;
                String body = arabic && bodyAr != null ? bodyAr : bodyEn;
                pushService.send(user.getPushToken(), user.getPushPlatform(), title, body, Map.of(
                        "notificationId", String.valueOf(saved.getId()),
                        "type", type.name(),
                        "relatedBookingId", relatedBookingId != null ? String.valueOf(relatedBookingId) : "",
                        "relatedProviderId", relatedProviderId != null ? String.valueOf(relatedProviderId) : ""
                ));
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
