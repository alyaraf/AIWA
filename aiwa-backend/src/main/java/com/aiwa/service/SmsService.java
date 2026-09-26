package com.aiwa.service;

public interface SmsService {
    void sendOtp(String phone, String code, int expiresInMinutes);
}
