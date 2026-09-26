package com.aiwa.service;

import com.aiwa.enums.DevicePlatform;

import java.util.Map;

/**
 * Delivers a push notification to one registered device. Implementations are
 * selected by {@code aiwa.push.provider} — see {@link com.aiwa.service.impl.DevLogPushService}
 * (default, logs only) and {@link com.aiwa.service.impl.FcmPushService} (real delivery).
 */
public interface PushNotificationService {
    void send(String deviceToken, DevicePlatform platform, String title, String body, Map<String, String> data);
}
