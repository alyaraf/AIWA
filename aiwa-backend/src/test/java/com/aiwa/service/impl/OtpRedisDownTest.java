package com.aiwa.service.impl;

import com.aiwa.exception.ServiceUnavailableException;
import com.aiwa.service.EmailService;
import com.aiwa.service.SmsService;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.RedisConnectionFailureException;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** L-8 (audit 2026-10-03): with Redis down, sending or checking a code is a 503, not an unexplained 500. */
class OtpRedisDownTest {

    private final RedisRuntimeService redis = mock(RedisRuntimeService.class);
    private final SmsService sms = mock(SmsService.class);
    private final OtpServiceImpl otp = new OtpServiceImpl(redis, sms, mock(EmailService.class));

    OtpRedisDownTest() {
        when(redis.increment(anyString(), any(Duration.class))).thenThrow(new RedisConnectionFailureException("down"));
    }

    @Test
    void sendingACodeAnswers503AndTextsNobody() {
        assertThatThrownBy(() -> otp.sendOtp("+201000000001"))
                .isInstanceOf(ServiceUnavailableException.class).hasMessage("otp.error.unavailable");
        verify(sms, never()).sendOtp(anyString(), anyString(), org.mockito.ArgumentMatchers.anyInt());
    }

    @Test
    void checkingACodeAnswers503() {
        assertThatThrownBy(() -> otp.verifyOtp("+201000000001", "123456"))
                .isInstanceOf(ServiceUnavailableException.class).hasMessage("otp.error.unavailable");
    }
}
