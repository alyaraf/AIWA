package com.aiwa.service.impl;

import com.aiwa.entity.PlatformSettings;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.PlatformSettingsRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class PlatformSettingsBookingRulesTest {

    private final PlatformSettingsRepository repo = mock(PlatformSettingsRepository.class);
    private PlatformSettingsServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new PlatformSettingsServiceImpl(repo);
        ReflectionTestUtils.setField(service, "defaultCommissionPercent", new BigDecimal("10"));
        ReflectionTestUtils.setField(service, "defaultCancellationCutoffHours", 2);
        ReflectionTestUtils.setField(service, "defaultProviderCancelPenaltyPercent", new BigDecimal("15"));
        ReflectionTestUtils.setField(service, "defaultResponseWindowMinutes", 120L);
        when(repo.save(any(PlatformSettings.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void fallsBackToConfigDefaultsWhenUnset() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.empty());
        assertThat(service.getCancellationCutoffHours()).isEqualTo(2);
        assertThat(service.getResponseWindowMinutes()).isEqualTo(120L);
        assertThat(service.getProviderCancelPenaltyPercent()).isEqualByComparingTo("15");
    }

    @Test
    void readsStoredBookingRules() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(PlatformSettings.builder()
                .id(1L).commissionPercent(new BigDecimal("10"))
                .cancellationCutoffHours(4).providerCancelPenaltyPercent(new BigDecimal("20"))
                .responseWindowMinutes(45L).build()));
        assertThat(service.getCancellationCutoffHours()).isEqualTo(4);
        assertThat(service.getResponseWindowMinutes()).isEqualTo(45L);
        assertThat(service.getProviderCancelPenaltyPercent()).isEqualByComparingTo("20");
    }

    @Test
    void updatePersistsProvidedFields() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(
                PlatformSettings.builder().id(1L).commissionPercent(new BigDecimal("10")).build()));
        PlatformSettings result = service.updateBookingRules(6, new BigDecimal("25"), 30L);
        assertThat(result.getCancellationCutoffHours()).isEqualTo(6);
        assertThat(result.getProviderCancelPenaltyPercent()).isEqualByComparingTo("25");
        assertThat(result.getResponseWindowMinutes()).isEqualTo(30L);
    }

    @Test
    void rejectsOutOfRangeRules() {
        assertThatThrownBy(() -> service.updateBookingRules(200, null, null)).isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> service.updateBookingRules(null, new BigDecimal("150"), null)).isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> service.updateBookingRules(null, null, 5000L)).isInstanceOf(BusinessException.class);
    }

    @Test
    void providerOverridesWinOverPlatformRules() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(PlatformSettings.builder()
                .id(1L).commissionPercent(new BigDecimal("10"))
                .cancellationCutoffHours(3).providerCancelPenaltyPercent(new BigDecimal("12"))
                .responseWindowMinutes(90L).build()));

        com.aiwa.entity.ProviderProfile p = com.aiwa.entity.ProviderProfile.builder()
                .cancellationCutoffHoursOverride(6)
                .responseWindowMinutesOverride(30L)
                .build(); // penalty override left null → falls back to platform

        assertThat(service.getCancellationCutoffHours(p)).isEqualTo(6);
        assertThat(service.getResponseWindowMinutes(p)).isEqualTo(30L);
        assertThat(service.getProviderCancelPenaltyPercent(p)).isEqualByComparingTo("12");
        // null provider → platform values
        assertThat(service.getCancellationCutoffHours((com.aiwa.entity.ProviderProfile) null)).isEqualTo(3);
    }
}
