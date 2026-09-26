package com.aiwa.controller;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.StaffMember;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.StaffMemberRepository;
import com.aiwa.service.impl.AuditService;
import com.aiwa.service.impl.PlatformSettingsServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AdminProviderSettingsControllerTest {

    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final StaffMemberRepository staffRepo = mock(StaffMemberRepository.class);
    private final PlatformSettingsServiceImpl platformSettings = mock(PlatformSettingsServiceImpl.class);
    private final AuditService auditService = mock(AuditService.class);

    private final AdminProviderSettingsController controller =
            new AdminProviderSettingsController(providerRepo, staffRepo, platformSettings, auditService);

    private ProviderProfile provider;

    @BeforeEach
    void setUp() {
        provider = ProviderProfile.builder().id(7L).businessName("Nadia Studio").build();
        when(providerRepo.findById(7L)).thenReturn(Optional.of(provider));
        when(providerRepo.save(any(ProviderProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        // toDto reads a handful of resolvers — stub loosely
        when(platformSettings.getCommissionPercent()).thenReturn(new BigDecimal("10"));
        when(platformSettings.getCommissionPercentFor(any())).thenReturn(new BigDecimal("10"));
        when(platformSettings.getCancellationCutoffHours()).thenReturn(2);
        when(platformSettings.getCancellationCutoffHours(any(ProviderProfile.class))).thenReturn(2);
        when(platformSettings.getProviderCancelPenaltyPercent()).thenReturn(new BigDecimal("15"));
        when(platformSettings.getProviderCancelPenaltyPercent(any(ProviderProfile.class))).thenReturn(new BigDecimal("15"));
        when(platformSettings.getResponseWindowMinutes()).thenReturn(120L);
        when(platformSettings.getResponseWindowMinutes(any(ProviderProfile.class))).thenReturn(120L);
        doThrow(new BusinessException("Commission percent must be between 0 and 100"))
                .when(platformSettings).validateCommissionPercent(argThat(v -> v == null
                        || v.signum() < 0 || v.compareTo(BigDecimal.valueOf(100)) > 0));
    }

    @Test
    void setsAndClearsCommissionOverride() {
        controller.updateCommission(7L, new BigDecimal("8.5"), false);
        assertThat(provider.getCommissionOverridePercent()).isEqualByComparingTo("8.5");
        verify(auditService).record(eq("PROVIDER_COMMISSION_UPDATED"), contains("8.5"));

        controller.updateCommission(7L, null, true);
        assertThat(provider.getCommissionOverridePercent()).isNull();
        verify(auditService).record(eq("PROVIDER_COMMISSION_UPDATED"), contains("platform"));
    }

    @Test
    void rejectsOutOfRangeCommission() {
        assertThatThrownBy(() -> controller.updateCommission(7L, new BigDecimal("120"), false))
                .isInstanceOf(BusinessException.class);
        assertThat(provider.getCommissionOverridePercent()).isNull();
    }

    @Test
    void setsBookingRuleOverridesThenClearsOne() {
        controller.updateBookingRules(7L, 6, new BigDecimal("20"), 45L, "");
        assertThat(provider.getCancellationCutoffHoursOverride()).isEqualTo(6);
        assertThat(provider.getProviderCancelPenaltyPercentOverride()).isEqualByComparingTo("20");
        assertThat(provider.getResponseWindowMinutesOverride()).isEqualTo(45L);

        controller.updateBookingRules(7L, null, null, null, "responseWindowMinutes");
        assertThat(provider.getResponseWindowMinutesOverride()).isNull();
        assertThat(provider.getCancellationCutoffHoursOverride()).isEqualTo(6); // untouched
    }

    @Test
    void bookingRulesValidationDelegatesToPlatformService() {
        doThrow(new BusinessException("bad")).when(platformSettings)
                .validateBookingRules(eq(999), any(), any());
        assertThatThrownBy(() -> controller.updateBookingRules(7L, 999, null, null, ""))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void staffListIncludesInactiveOnes_unlikeThePublicProviderEndpoint() {
        when(staffRepo.findByProviderIdOrderByFullNameAsc(7L)).thenReturn(List.of(
                StaffMember.builder().id(1L).provider(provider).fullName("Salma").active(true).build(),
                StaffMember.builder().id(2L).provider(provider).fullName("Dina").active(false).build()
        ));

        var rows = controller.staff(7L).getBody().getData();

        assertThat(rows).hasSize(2);
        assertThat(rows).anyMatch(s -> !s.isActive());
    }
}
