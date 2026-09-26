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

class PlatformSettingsServiceTest {

    private final PlatformSettingsRepository repo = mock(PlatformSettingsRepository.class);
    private PlatformSettingsServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new PlatformSettingsServiceImpl(repo);
        ReflectionTestUtils.setField(service, "defaultCommissionPercent", new BigDecimal("10"));
        when(repo.save(any(PlatformSettings.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void fallsBackToDefaultWhenNoRow() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.empty());
        assertThat(service.getCommissionPercent()).isEqualByComparingTo("10");
    }

    @Test
    void readsStoredRate() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(
                PlatformSettings.builder().id(1L).commissionPercent(new BigDecimal("12.5")).build()));
        assertThat(service.getCommissionPercent()).isEqualByComparingTo("12.5");
    }

    @Test
    void updateSeedsRowWhenMissingAndPersists() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.empty());
        PlatformSettings result = service.updateCommissionPercent(new BigDecimal("15"));
        assertThat(result.getCommissionPercent()).isEqualByComparingTo("15");
        verify(repo, atLeastOnce()).save(any(PlatformSettings.class));
    }

    @Test
    void rejectsOutOfRange() {
        assertThatThrownBy(() -> service.updateCommissionPercent(new BigDecimal("-1")))
                .isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> service.updateCommissionPercent(new BigDecimal("101")))
                .isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> service.updateCommissionPercent(null))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void providerOverrideWinsOverPlatformRate() {
        when(repo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(
                PlatformSettings.builder().id(1L).commissionPercent(new BigDecimal("10")).build()));

        com.aiwa.entity.ProviderProfile withOverride = com.aiwa.entity.ProviderProfile.builder()
                .commissionOverridePercent(new BigDecimal("7.5")).build();
        com.aiwa.entity.ProviderProfile noOverride = com.aiwa.entity.ProviderProfile.builder().build();

        assertThat(service.getCommissionPercentFor(withOverride)).isEqualByComparingTo("7.5");
        assertThat(service.getCommissionPercentFor(noOverride)).isEqualByComparingTo("10");
        assertThat(service.getCommissionPercentFor(null)).isEqualByComparingTo("10");
    }
}
