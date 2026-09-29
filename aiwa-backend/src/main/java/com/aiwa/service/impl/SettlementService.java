package com.aiwa.service.impl;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.enums.LedgerEntryStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Commission settlement rules. Nothing ever moved a ledger entry to OVERDUE
 * before — the admin "Overdue" status and the provider's balance limit existed
 * only on screen. The sweep now marks entries OVERDUE after
 * {@code aiwa.settlement.due-days} and pauses new bookings for a provider who
 * has overdue commission or owes more than {@code aiwa.settlement.balance-limit}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SettlementService {

    private static final Set<LedgerEntryStatus> OUTSTANDING = Set.of(LedgerEntryStatus.DUE, LedgerEntryStatus.OVERDUE);

    private final CommissionLedgerRepository ledgerRepo;
    private final ProviderProfileRepository providerRepo;
    private final NotificationServiceImpl notificationService;

    @Value("${aiwa.settlement.balance-limit:1000}")
    private BigDecimal balanceLimit = new BigDecimal("1000");

    @Value("${aiwa.settlement.due-days:7}")
    private int dueDays = 7;

    public BigDecimal balanceLimit() {
        return balanceLimit;
    }

    public int dueDays() {
        return dueDays;
    }

    /** True when the provider has nothing overdue and owes less than the limit. */
    @Transactional(readOnly = true)
    public boolean mayResumeBookings(ProviderProfile provider) {
        List<CommissionLedgerEntry> open = ledgerRepo.findByProviderIdAndStatusIn(provider.getId(), OUTSTANDING);
        boolean overdue = open.stream().anyMatch(e -> e.getStatus() == LedgerEntryStatus.OVERDUE);
        BigDecimal owed = open.stream().map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        return !overdue && owed.compareTo(balanceLimit) < 0;
    }

    /**
     * Marks DUE entries older than the due period OVERDUE, then pauses providers
     * that are overdue or over the balance limit (notifying them once).
     *
     * @return number of providers newly paused
     */
    @Transactional
    public int sweep() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(dueDays);
        List<CommissionLedgerEntry> becameOverdue = ledgerRepo.findByStatusOrderByCreatedAtAsc(LedgerEntryStatus.DUE)
                .stream()
                .filter(e -> e.getCreatedAt() != null && e.getCreatedAt().isBefore(cutoff))
                .toList();
        becameOverdue.forEach(e -> e.setStatus(LedgerEntryStatus.OVERDUE));
        ledgerRepo.saveAll(becameOverdue);

        Map<Long, List<CommissionLedgerEntry>> openByProvider = ledgerRepo
                .findByStatusIn(OUTSTANDING).stream()
                .collect(Collectors.groupingBy(e -> e.getProvider().getId()));

        int paused = 0;
        for (List<CommissionLedgerEntry> entries : openByProvider.values()) {
            ProviderProfile provider = entries.get(0).getProvider();
            if (provider.isSettlementPaused()) continue;
            boolean overdue = entries.stream().anyMatch(e -> e.getStatus() == LedgerEntryStatus.OVERDUE);
            BigDecimal owed = entries.stream().map(CommissionLedgerEntry::getCommissionAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            if (!overdue && owed.compareTo(balanceLimit) < 0) continue;

            provider.setSettlementPaused(true);
            providerRepo.save(provider);
            paused++;
            notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_OVERDUE,
                    "New bookings paused", "تم إيقاف الحجوزات الجديدة",
                    "You owe EGP " + owed + " in commission" + (overdue ? ", part of it overdue" : "")
                            + ". Settle your balance to receive new bookings again.",
                    "عليك عمولة " + owed + " جنيه" + (overdue ? " وجزء منها متأخر" : "")
                            + ". سدد رصيدك لتستقبل حجوزات جديدة مرة أخرى.",
                    null, provider.getId());
        }
        if (!becameOverdue.isEmpty() || paused > 0) {
            log.info("Settlement sweep: {} entr(y/ies) overdue, {} provider(s) paused", becameOverdue.size(), paused);
        }
        return paused;
    }
}
