package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.exception.TooManyRequestsException;
import com.aiwa.service.EmailService;
import com.aiwa.service.SmsService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Locale;

/**
 * One-time codes for sign-up and password reset, by SMS (phone) or email.
 *
 * <p>Codes come from {@link SecureRandom} (java.util.Random is predictable), are
 * compared in constant time, allow 5 guesses each, and each destination can only
 * be sent a limited number of codes (default 3 per 10 minutes, 10 per day) — on
 * top of the per-IP limit in RedisRateLimitFilter — so the endpoint can't be used
 * to pump paid SMS to one number or to brute-force a code by re-sending.</p>
 */
@Service
@RequiredArgsConstructor
public class OtpServiceImpl {

    private static final Duration OTP_TTL = Duration.ofMinutes(10);
    private static final int OTP_TTL_MINUTES = 10;
    private static final Duration VERIFIED_TTL = Duration.ofMinutes(30);
    private static final int MAX_VERIFY_ATTEMPTS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final RedisRuntimeService redis;
    private final SmsService smsService;
    private final EmailService emailService;

    @Value("${aiwa.otp.max-sends-per-10-minutes:3}")
    private int maxSendsPer10Minutes = 3;

    @Value("${aiwa.otp.max-sends-per-day:10}")
    private int maxSendsPerDay = 10;

    // ── phone (SMS) ──────────────────────────────────────────────────────────

    public void sendOtp(String phone) {
        String code = issue(phone);
        smsService.sendOtp(phone, code, OTP_TTL_MINUTES);
    }

    public void verifyOtp(String phone, String code) {
        verify(phone, code);
    }

    public boolean isPhoneVerified(String phone) {
        return isVerified(phone);
    }

    public void consumePhoneVerification(String phone) {
        consume(phone);
    }

    // ── email ────────────────────────────────────────────────────────────────

    public void sendEmailOtp(String email) {
        String id = normalizeEmail(email);
        String code = issue(id);
        emailService.send(id, "Your AIWA verification code",
                "Your AIWA verification code is " + code + ". It expires in " + OTP_TTL_MINUTES
                        + " minutes. If you didn't ask for it, you can ignore this email.");
    }

    public void verifyEmailOtp(String email, String code) {
        verify(normalizeEmail(email), code);
    }

    public boolean isEmailVerified(String email) {
        return email != null && isVerified(normalizeEmail(email));
    }

    public void consumeEmailVerification(String email) {
        if (email != null) consume(normalizeEmail(email));
    }

    public static String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    // ── shared ───────────────────────────────────────────────────────────────

    private String issue(String identifier) {
        long recent = redis.increment(sendsKey(identifier, "10m"), Duration.ofMinutes(10));
        long daily = redis.increment(sendsKey(identifier, "day"), Duration.ofDays(1));
        if (recent > maxSendsPer10Minutes || daily > maxSendsPerDay) {
            throw new TooManyRequestsException("otp.error.too_many_sends");
        }
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        redis.set(otpKey(identifier), code, OTP_TTL);
        redis.delete(attemptKey(identifier));
        redis.delete(verifiedKey(identifier));
        return code;
    }

    private void verify(String identifier, String code) {
        long attempts = redis.increment(attemptKey(identifier), OTP_TTL);
        if (attempts > MAX_VERIFY_ATTEMPTS) {
            throw new BusinessException("otp.error.too_many_attempts");
        }

        String savedCode = redis.get(otpKey(identifier))
                .orElseThrow(() -> new BusinessException("otp.error.expired"));

        if (code == null || !MessageDigest.isEqual(savedCode.getBytes(StandardCharsets.UTF_8),
                code.trim().getBytes(StandardCharsets.UTF_8))) {
            throw new BusinessException("otp.error.incorrect");
        }

        redis.delete(otpKey(identifier));
        redis.delete(attemptKey(identifier));
        redis.set(verifiedKey(identifier), "1", VERIFIED_TTL);
    }

    private boolean isVerified(String identifier) {
        return identifier != null && redis.exists(verifiedKey(identifier));
    }

    private void consume(String identifier) {
        if (identifier != null) {
            redis.delete(verifiedKey(identifier));
        }
    }

    private String otpKey(String id) {
        return "otp:code:" + id;
    }

    private String attemptKey(String id) {
        return "otp:attempts:" + id;
    }

    private String verifiedKey(String id) {
        return "otp:verified:" + id;
    }

    private String sendsKey(String id, String window) {
        return "otp:sends:" + window + ":" + id;
    }
}
