package com.aiwa.service;

public interface SmsService {
    void sendOtp(String phone, String code, int expiresInMinutes);

    /** Free-text SMS (safety alerts to on-call support and trusted contacts). */
    void send(String phone, String message);
}
