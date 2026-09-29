package com.aiwa.service.impl;

import com.aiwa.service.EmailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.email.provider", havingValue = "dev-log", matchIfMissing = true)
public class DevLogEmailService implements EmailService {

    @Override
    public void send(String to, String subject, String text) {
        log.info("[DEV EMAIL] -> {} : {} — {}", to, subject, text);
    }
}
