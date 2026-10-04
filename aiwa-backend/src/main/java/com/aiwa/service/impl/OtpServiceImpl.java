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
@lombok.extern.slf4j.Slf4j
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

    static final String OTP_SENT_METRIC = "aiwa.otp.sent";
    static final String OTP_BUDGET_METRIC = "aiwa.otp.global_budget_exhausted";
    private static final String GLOBAL_HOUR_KEY = "otp:global:hour";
    private static final String GLOBAL_DAY_KEY = "otp:global:day";

    @Value("${aiwa.otp.allowed-country-codes:20}")
    private java.util.List<String> allowedCountryCodes = java.util.List.of("20");

    @Value("${aiwa.otp.max-global-sends-per-hour:1000}")
    private long maxGlobalSendsPerHour = 1000;

    @Value("${aiwa.otp.max-global-sends-per-day:10000}")
    private long maxGlobalSendsPerDay = 10000;

    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMeterRegistry(io.micrometer.core.instrument.MeterRegistry registry) {
        this.meterRegistry = registry;
    }

    // ── phone (SMS) ──────────────────────────────────────────────────────────

    // Codes are keyed on the normalized number (R2-19), so a code sent to
    // 010… verifies a sign-up for +2010… and vice versa.

    public void sendOtp(String phone) {
        String id = com.aiwa.util.Identifiers.normalizePhone(phone);
        requireAllowedCountry(id);
        whileRedisIsUp(() -> {
            requireGlobalBudget();
            return null;
        });
        String code = issue(id);
        smsService.sendOtp(id, code, OTP_TTL_MINUTES);
        if (meterRegistry != null) meterRegistry.counter(OTP_SENT_METRIC, "channel", "sms").increment();
    }

    /**
     * H-4: only numbers in the allowed country codes are texted (default Egypt, +20).
     * SMS pumping sends codes to premium-rate ranges abroad; an empty list allows all.
     */
    void requireAllowedCountry(String e164) {
        if (allowedCountryCodes.isEmpty()) return;
        if (e164 != null && e164.startsWith("+")) {
            for (String cc : allowedCountryCodes) {
                if (e164.startsWith("+" + cc)) return;
            }
        }
        throw new BusinessException("otp.error.country_not_supported");
    }

    /**
     * H-4: a ceiling on all OTP texts per hour and per day, across every number and
     * IP, so a distributed attack can't run up an unbounded SMS bill. Hitting it is
     * counted (alert OtpGlobalBudgetExhausted) and answered 429.
     */
    void requireGlobalBudget() {
        long hour = redis.increment(GLOBAL_HOUR_KEY, Duration.ofHours(1));
        long day = redis.increment(GLOBAL_DAY_KEY, Duration.ofDays(1));
        if ((maxGlobalSendsPerHour > 0 && hour > maxGlobalSendsPerHour)
                || (maxGlobalSendsPerDay > 0 && day > maxGlobalSendsPerDay)) {
            if (meterRegistry != null) meterRegistry.counter(OTP_BUDGET_METRIC).increment();
            log.warn("OTP global budget exhausted ({} this hour, {} today)", hour, day);
            throw new TooManyRequestsException("otp.error.busy");
        }
    }

    public void verifyOtp(String phone, String code) {
        verify(com.aiwa.util.Identifiers.normalizePhone(phone), code);
    }

    public boolean isPhoneVerified(String phone) {
        return isVerified(com.aiwa.util.Identifiers.normalizePhone(phone));
    }

    public void consumePhoneVerification(String phone) {
        consume(com.aiwa.util.Identifiers.normalizePhone(phone));
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

    /**
     * L-8: Redis holds the codes; while it is down sending and checking a code answers 503
     * (otp.error.unavailable) and an alert-worthy log line, not an unexplained 500.
     */
    private <T> T whileRedisIsUp(java.util.function.Supplier<T> work) {
        try {
            return work.get();
        } catch (org.springframework.dao.DataAccessException e) {
            log.error("OTP unavailable, Redis is down: {}", e.getMessage());
            throw new com.aiwa.exception.ServiceUnavailableException("otp.error.unavailable");
        }
    }

    private String issue(String identifier) {
        return whileRedisIsUp(() -> issueCode(identifier));
    }

    private String issueCode(String identifier) {
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
        whileRedisIsUp(() -> {
            verifyCode(identifier, code);
            return null;
        });
    }

    private void verifyCode(String identifier, String code) {
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

        // Spend the code atomically (DR-016): of two parallel checks with the
        // right code only one passes; the other sees it as already used.
        if (!redis.compareAndDelete(otpKey(identifier), savedCode)) {
            throw new BusinessException("otp.error.expired");
        }
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
