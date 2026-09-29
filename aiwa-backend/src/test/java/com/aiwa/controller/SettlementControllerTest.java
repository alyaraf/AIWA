package com.aiwa.controller;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.LedgerEntryStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.NotificationServiceImpl;
import com.aiwa.service.impl.SettlementService;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
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
    private final SettlementService settlementService = mock(SettlementService.class);

    private final SettlementController controller = new SettlementController(
            ledgerRepo, providerRepo, userRepo, notificationService, auditService, platformSettings, settlementService);

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_PROVIDER")));
    }

    private ProviderProfile providerFor(String username) {
        User u = User.builder().id(50L).email(username).role(UserRole.PROVIDER).build();
        ProviderProfile p = ProviderProfile.builder().id(7L).user(u).businessName("Studio").settlementPaused(true).build();
        when(userRepo.findByEmail(username)).thenReturn(Optional.of(u));
        when(providerRepo.findByUserId(50L)).thenReturn(Optional.of(p));
        return p;
    }

    /**
     * Regression for the self-settle hole: "pay" used to mark every entry SETTLED
     * and lift the pause on the provider's word alone. It must only record the
     * report and alert finance; the debt stays until an admin confirms the payout.
     */
    @Test
    void providerReportingPaymentDoesNotSettleOrUnpause() {
        ProviderProfile p = providerFor("prov@x.com");
        CommissionLedgerEntry e = CommissionLedgerEntry.builder()
                .id(1L).provider(p).commissionAmount(new BigDecimal("10")).status(LedgerEntryStatus.DUE).build();
        when(ledgerRepo.findByProviderIdAndStatusIn(eq(7L), anyCollection())).thenReturn(List.of(e));
        when(ledgerRepo.findByProviderIdOrderByCreatedAtDesc(7L)).thenReturn(List.of(e));
        User finance = User.builder().id(90L).role(UserRole.ADMIN).active(true)
                .adminPermissions(Set.of(AdminPermission.FINANCE)).build();
        User support = User.builder().id(91L).role(UserRole.ADMIN).active(true)
                .adminPermissions(Set.of(AdminPermission.SUPPORT)).build();
        when(userRepo.findByRoleAndActive(UserRole.ADMIN, true)).thenReturn(List.of(finance, support));

        var res = controller.payDues(principal("prov@x.com"));

        assertThat(e.getStatus()).isEqualTo(LedgerEntryStatus.DUE);
        verify(ledgerRepo, never()).saveAll(any());
        assertThat(p.isSettlementPaused()).isTrue();
        assertThat(p.getSettlementReportedAt()).isNotNull();
        assertThat(res.getBody().getData().getPaymentReportedAt()).isNotNull();
        assertThat(res.getBody().getData().getOwedAmount()).isEqualByComparingTo("10");
        // finance is told, support-only admins are not; the provider gets a receipt
        verify(notificationService).send(eq(90L), eq(NotificationType.SETTLEMENT_REPORTED), any(), any(), any(), any(), any(), any());
        verify(notificationService, never()).send(eq(91L), any(), any(), any(), any(), any(), any(), any());
        verify(notificationService).send(eq(50L), eq(NotificationType.SETTLEMENT_REPORTED), any(), any(), any(), any(), any(), any());
    }

    @Test
    void summaryCountsOverdueEntriesAsOwed() {
        ProviderProfile p = providerFor("prov@x.com");
        CommissionLedgerEntry due = CommissionLedgerEntry.builder()
                .id(1L).provider(p).commissionAmount(new BigDecimal("10")).status(LedgerEntryStatus.DUE).build();
        CommissionLedgerEntry overdue = CommissionLedgerEntry.builder()
                .id(2L).provider(p).commissionAmount(new BigDecimal("25")).status(LedgerEntryStatus.OVERDUE).build();
        when(ledgerRepo.findByProviderIdOrderByCreatedAtDesc(7L)).thenReturn(List.of(due, overdue));
        when(settlementService.balanceLimit()).thenReturn(new BigDecimal("1000"));

        var dto = controller.providerSettlement(principal("prov@x.com")).getBody().getData();

        assertThat(dto.getDueAmount()).isEqualByComparingTo("35");
        assertThat(dto.getOverdueAmount()).isEqualByComparingTo("25");
        assertThat(dto.getBalanceLimit()).isEqualByComparingTo("1000");
        assertThat(dto.getStatus()).isEqualTo("OVERDUE");
    }

    @Test
    void payingWithNoDuesFails() {
        providerFor("prov@x.com");
        when(ledgerRepo.findByProviderIdAndStatusIn(eq(7L), anyCollection())).thenReturn(List.of());

        assertThatThrownBy(() -> controller.payDues(principal("prov@x.com")))
                .isInstanceOf(BusinessException.class).hasMessageContaining("No outstanding");
    }
}
