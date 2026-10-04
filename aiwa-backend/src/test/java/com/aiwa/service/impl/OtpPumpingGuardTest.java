package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.exception.TooManyRequestsException;
import com.aiwa.service.EmailService;
import com.aiwa.service.SmsService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

/** H-4 (audit 2026-10-03): OTP texts only to allowed countries, and a global budget across all numbers. */
class OtpPumpingGuardTest {

    private final SmsService sms = mock(SmsService.class);
    private final OtpServiceImpl otp = new OtpServiceImpl(new InMemoryRedisRuntimeService(), sms, mock(EmailService.class));
    private final SimpleMeterRegistry meters = new SimpleMeterRegistry();

    @BeforeEach
    void setUp() {
        otp.setMeterRegistry(meters);
    }

    @Test
    void anEgyptianNumberInAnyFormIsTexted() {
        otp.sendOtp("01001234567");
        verify(sms).sendOtp(eq("+201001234567"), anyString(), anyInt());
        assertThat(meters.counter(OtpServiceImpl.OTP_SENT_METRIC, "channel", "sms").count()).isEqualTo(1);
    }

    @Test
    void aForeignNumberIsRefusedBeforeAnythingIsSent() {
        assertThatThrownBy(() -> otp.sendOtp("+88213000001"))
                .isInstanceOf(BusinessException.class).hasMessage("otp.error.country_not_supported");
        verify(sms, never()).sendOtp(anyString(), anyString(), anyInt());
    }

    @Test
    void theAllowListIsConfigurableAndEmptyMeansAnyCountry() {
        ReflectionTestUtils.setField(otp, "allowedCountryCodes", List.of("20", "966"));
        assertThatCode(() -> otp.sendOtp("+966500000001")).doesNotThrowAnyException();
        ReflectionTestUtils.setField(otp, "allowedCountryCodes", List.of());
        assertThatCode(() -> otp.sendOtp("+447700900001")).doesNotThrowAnyException();
    }

    @Test
    void theGlobalHourlyBudgetStopsSendsAcrossDifferentNumbers() {
        ReflectionTestUtils.setField(otp, "maxGlobalSendsPerHour", 3L);
        for (int i = 0; i < 3; i++) otp.sendOtp("+20100000000" + i);
        assertThatThrownBy(() -> otp.sendOtp("+201000000009"))
                .isInstanceOf(TooManyRequestsException.class).hasMessage("otp.error.busy");
        verify(sms, times(3)).sendOtp(anyString(), anyString(), anyInt());
        assertThat(meters.counter(OtpServiceImpl.OTP_BUDGET_METRIC).count()).isEqualTo(1);
    }
}
