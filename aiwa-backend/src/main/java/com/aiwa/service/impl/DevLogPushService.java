package com.aiwa.service.impl;

import com.aiwa.enums.DevicePlatform;
import com.aiwa.service.PushNotificationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.util.Map;

@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.push.provider", havingValue = "dev-log", matchIfMissing = true)
public class DevLogPushService implements PushNotificationService {

    @Override
    public void send(String deviceToken, DevicePlatform platform, String title, String body, Map<String, String> data) {
        log.info("[DEV PUSH] -> {} ({}) : {} - {} {}", deviceToken, platform, title, body, data);
    }
}
