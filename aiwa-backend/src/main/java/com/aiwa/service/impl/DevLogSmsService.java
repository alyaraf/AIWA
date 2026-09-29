package com.aiwa.service.impl;

import com.aiwa.service.SmsService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.sms.provider", havingValue = "dev-log", matchIfMissing = true)
public class DevLogSmsService implements SmsService {

    @Override
    public void sendOtp(String phone, String code, int expiresInMinutes) {
        log.info("[DEV SMS] OTP for {} is {} and expires in {} minutes", phone, code, expiresInMinutes);
    }

    @Override
    public void send(String phone, String message) {
        log.info("[DEV SMS] -> {} : {}", phone, message);
    }
}
