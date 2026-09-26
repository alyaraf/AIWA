package com.aiwa.controller;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.LedgerEntryStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class SettlementControllerTest {

    private final CommissionLedgerRepository ledgerRepo = mock(CommissionLedgerRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final com.aiwa.service.impl.AuditService auditService = mock(com.aiwa.service.impl.AuditService.class);
    private final com.aiwa.service.impl.PlatformSettingsServiceImpl platformSettings = mock(com.aiwa.service.impl.PlatformSettingsServiceImpl.class);

    private final SettlementController controller =
            new SettlementController(ledgerRepo, providerRepo, userRepo, notificationService, auditService, platformSettings);

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_PROVIDER")));
    }

    private ProviderProfile providerFor(String username) {
        User u = User.builder().id(50L).email(username).role(UserRole.PROVIDER).build();
        ProviderProfile p = ProviderProfile.builder().id(7L).user(u).settlementPaused(true).build();
        when(userRepo.findByEmail(username)).thenReturn(Optional.of(u));
        when(providerRepo.findByUserId(50L)).thenReturn(Optional.of(p));
        return p;
    }

    @Test
    void providerSettlesOutstandingDues() {
        ProviderProfile p = providerFor("prov@x.com");
        CommissionLedgerEntry e = CommissionLedgerEntry.builder()
                .id(1L).provider(p).commissionAmount(new BigDecimal("10")).status(LedgerEntryStatus.DUE).build();
        when(ledgerRepo.findByProviderIdAndStatusIn(eq(7L), anyCollection())).thenReturn(List.of(e));
        when(ledgerRepo.findByProviderIdOrderByCreatedAtDesc(7L)).thenReturn(List.of(e));
        when(ledgerRepo.sumByProviderAndStatus(eq(7L), any())).thenReturn(BigDecimal.ZERO);

        controller.payDues(principal("prov@x.com"));

        verify(ledgerRepo).saveAll(argThat((Iterable<CommissionLedgerEntry> it) ->
                it.iterator().next().getStatus() == LedgerEntryStatus.SETTLED));
        verify(providerRepo).save(argThat(pp -> !pp.isSettlementPaused()));
        verify(notificationService).send(eq(50L), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void payingWithNoDuesFails() {
        providerFor("prov@x.com");
        when(ledgerRepo.findByProviderIdAndStatusIn(eq(7L), anyCollection())).thenReturn(List.of());

        assertThatThrownBy(() -> controller.payDues(principal("prov@x.com")))
                .isInstanceOf(BusinessException.class).hasMessageContaining("No outstanding");
    }
}
