package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.service.SmsService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class OtpServiceImpl {

    private static final Duration OTP_TTL = Duration.ofMinutes(10);
    private static final int OTP_TTL_MINUTES = 10;
    private static final Duration VERIFIED_TTL = Duration.ofMinutes(30);
    private static final int MAX_VERIFY_ATTEMPTS = 5;

    private final RedisRuntimeService redis;
    private final SmsService smsService;

    public void sendOtp(String phone) {
        String code = String.format("%06d", new Random().nextInt(999999));
        redis.set(otpKey(phone), code, OTP_TTL);
        redis.delete(attemptKey(phone));
        redis.delete(verifiedKey(phone));

        smsService.sendOtp(phone, code, OTP_TTL_MINUTES);
    }

    public void verifyOtp(String phone, String code) {
        long attempts = redis.increment(attemptKey(phone), OTP_TTL);
        if (attempts > MAX_VERIFY_ATTEMPTS) {
            throw new BusinessException("otp.error.too_many_attempts");
        }

        String savedCode = redis.get(otpKey(phone))
                .orElseThrow(() -> new BusinessException("otp.error.expired"));

        if (!savedCode.equals(code)) {
            throw new BusinessException("otp.error.incorrect");
        }

        redis.delete(otpKey(phone));
        redis.delete(attemptKey(phone));
        redis.set(verifiedKey(phone), "1", VERIFIED_TTL);
    }

    public boolean isPhoneVerified(String phone) {
        return phone != null && redis.exists(verifiedKey(phone));
    }

    public void consumePhoneVerification(String phone) {
        if (phone != null) {
            redis.delete(verifiedKey(phone));
        }
    }

    private String otpKey(String phone) {
        return "otp:code:" + phone;
    }

    private String attemptKey(String phone) {
        return "otp:attempts:" + phone;
    }

    private String verifiedKey(String phone) {
        return "otp:verified:" + phone;
    }
}
