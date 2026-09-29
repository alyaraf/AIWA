package com.aiwa.service.impl;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.LedgerEntryStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class SettlementServiceTest {

    private final CommissionLedgerRepository ledgerRepo = mock(CommissionLedgerRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final NotificationServiceImpl notifications = mock(NotificationServiceImpl.class);
    private final SettlementService service = new SettlementService(ledgerRepo, providerRepo, notifications);

    private static ProviderProfile provider(long id) {
        return ProviderProfile.builder().id(id).user(User.builder().id(id * 10).build()).build();
    }

    private static CommissionLedgerEntry entry(ProviderProfile p, String amount, LedgerEntryStatus status, int daysOld) {
        CommissionLedgerEntry e = CommissionLedgerEntry.builder().provider(p)
                .commissionAmount(new BigDecimal(amount)).status(status).build();
        e.setCreatedAt(LocalDateTime.now().minusDays(daysOld));
        return e;
    }

    @Test
    void oldDueEntriesBecomeOverdueAndPauseTheProvider() {
        ProviderProfile late = provider(1);
        CommissionLedgerEntry old = entry(late, "40", LedgerEntryStatus.DUE, 10);
        CommissionLedgerEntry fresh = entry(late, "20", LedgerEntryStatus.DUE, 1);
        when(ledgerRepo.findByStatusOrderByCreatedAtAsc(LedgerEntryStatus.DUE)).thenReturn(List.of(old, fresh));
        when(ledgerRepo.findByStatusIn(anyCollection())).thenReturn(List.of(old, fresh));

        int paused = service.sweep();

        assertThat(old.getStatus()).isEqualTo(LedgerEntryStatus.OVERDUE);
        assertThat(fresh.getStatus()).isEqualTo(LedgerEntryStatus.DUE);
        assertThat(paused).isEqualTo(1);
        assertThat(late.isSettlementPaused()).isTrue();
        verify(notifications).send(eq(10L), eq(NotificationType.SETTLEMENT_OVERDUE), any(), any(), any(), any(), any(), any());
    }

    @Test
    void aProviderUnderTheLimitWithNothingOverdueKeepsTakingBookings() {
        ProviderProfile ok = provider(2);
        CommissionLedgerEntry e = entry(ok, "50", LedgerEntryStatus.DUE, 1);
        when(ledgerRepo.findByStatusOrderByCreatedAtAsc(LedgerEntryStatus.DUE)).thenReturn(List.of(e));
        when(ledgerRepo.findByStatusIn(anyCollection())).thenReturn(List.of(e));

        assertThat(service.sweep()).isZero();
        assertThat(ok.isSettlementPaused()).isFalse();
    }

    @Test
    void owingMoreThanTheLimitPausesEvenWithoutOverdue() {
        ProviderProfile big = provider(3);
        CommissionLedgerEntry e = entry(big, "1500", LedgerEntryStatus.DUE, 1);
        when(ledgerRepo.findByStatusOrderByCreatedAtAsc(LedgerEntryStatus.DUE)).thenReturn(List.of(e));
        when(ledgerRepo.findByStatusIn(anyCollection())).thenReturn(List.of(e));

        assertThat(service.sweep()).isEqualTo(1);
        assertThat(big.isSettlementPaused()).isTrue();
    }
}
