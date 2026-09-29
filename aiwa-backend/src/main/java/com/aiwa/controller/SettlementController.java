package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.NotificationServiceImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import com.aiwa.security.Perms;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class SettlementController {

    private final CommissionLedgerRepository ledgerRepo;
    private final ProviderProfileRepository providerRepo;
    private final UserRepository userRepo;
    private final NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AuditService auditService;
    private final com.aiwa.service.impl.PlatformSettingsServiceImpl platformSettings;
    private final com.aiwa.service.impl.SettlementService settlementService;

    private static final java.util.Set<LedgerEntryStatus> OUTSTANDING =
            java.util.Set.of(LedgerEntryStatus.DUE, LedgerEntryStatus.OVERDUE);

    @GetMapping("/provider/settlement")
    @PreAuthorize("hasRole('PROVIDER')")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementSummaryDto>> providerSettlement(
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        return ResponseEntity.ok(ApiResponse.Success.of(toSummary(provider)));
    }

    /**
     * The provider reports that they paid their outstanding commission (cash
     * hand-over or transfer). This used to mark every entry SETTLED and lift the
     * booking pause on the provider's own word — any provider could wipe their
     * debt with one call. Now it only records the claim and alerts finance; the
     * entries stay outstanding until an admin with FINANCE confirms the payout
     * (POST /admin/settlements/provider/{id}/confirm-payout).
     */
    @PatchMapping("/provider/settlement/pay")
    @PreAuthorize("hasRole('PROVIDER')")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementSummaryDto>> payDues(
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        List<CommissionLedgerEntry> outstanding = ledgerRepo.findByProviderIdAndStatusIn(
                provider.getId(), List.of(LedgerEntryStatus.DUE, LedgerEntryStatus.OVERDUE));
        if (outstanding.isEmpty()) {
            throw new com.aiwa.exception.BusinessException("No outstanding balance to settle");
        }
        BigDecimal owed = outstanding.stream().map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        provider.setSettlementReportedAt(LocalDateTime.now());
        providerRepo.save(provider);
        auditService.record("SETTLEMENT_REPORTED_BY_PROVIDER", provider.getBusinessName() + " · EGP " + owed);

        userRepo.findByRoleAndActive(UserRole.ADMIN, true).stream()
                .filter(a -> a.hasPermission(AdminPermission.FINANCE) || a.hasPermission(AdminPermission.SUPER_ADMIN))
                .forEach(a -> notificationService.send(a.getId(), NotificationType.SETTLEMENT_REPORTED,
                        "Commission payment reported", "تم الإبلاغ عن سداد عمولة",
                        provider.getBusinessName() + " reports paying EGP " + owed + ". Confirm the payout once received.",
                        provider.getBusinessName() + " يبلغ عن سداد " + owed + " جنيه. أكد الاستلام عند وصوله.",
                        null, provider.getId()));
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_REPORTED,
                "Payment reported", "تم الإبلاغ عن السداد",
                "Thanks — AIWA finance will confirm your EGP " + owed + " payment shortly.",
                "شكراً — سيؤكد فريق المالية في AIWA سداد " + owed + " جنيه قريباً.",
                null, provider.getId());

        return ResponseEntity.ok(ApiResponse.Success.of(
                "Payment reported — finance will confirm it", toSummary(provider)));
    }

    @GetMapping("/admin/settlements")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.CommissionLedgerDto>>> dueEntries(
            @RequestParam(defaultValue = "DUE") LedgerEntryStatus status) {
        return ResponseEntity.ok(ApiResponse.Success.of(ledgerRepo.findByStatusOrderByCreatedAtAsc(status)
                .stream().map(this::toDto).toList()));
    }

    // ── Admin Settlements screen: overview cards + per-provider rows ──────────

    @GetMapping("/admin/settlements/overview")
    @PreAuthorize("hasRole('ADMIN')")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementOverviewDto>> overview() {
        List<ApiResponse.SettlementRowDto> rows = providerRows();
        BigDecimal totalOwed = rows.stream()
                .map(ApiResponse.SettlementRowDto::getBalanceOwed)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        int owing = (int) rows.stream().filter(r -> r.getBalanceOwed().signum() > 0).count();
        return ResponseEntity.ok(ApiResponse.Success.of(ApiResponse.SettlementOverviewDto.builder()
                .commissionPercent(platformSettings.getCommissionPercent())
                .totalOwed(totalOwed)
                .providerCount(owing)
                .build()));
    }

    @GetMapping("/admin/settlements/providers")
    @PreAuthorize("hasRole('ADMIN')")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.SettlementRowDto>>> providers() {
        return ResponseEntity.ok(ApiResponse.Success.of(providerRows()));
    }

    @GetMapping("/admin/settlements/provider/{providerId}")
    @PreAuthorize("hasRole('ADMIN')")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementDetailDto>> providerDetail(
            @PathVariable Long providerId) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        List<CommissionLedgerEntry> all = ledgerRepo.findByProviderIdOrderByCreatedAtDesc(providerId);
        BigDecimal owed = all.stream()
                .filter(e -> OUTSTANDING.contains(e.getStatus()))
                .map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        return ResponseEntity.ok(ApiResponse.Success.of(ApiResponse.SettlementDetailDto.builder()
                .providerId(providerId)
                .providerName(provider.getBusinessName())
                .settlementPaused(provider.isSettlementPaused())
                .status(statusOf(all))
                .commissionPercent(platformSettings.getCommissionPercentFor(provider))
                .commissionOverridePercent(provider.getCommissionOverridePercent())
                .platformCommissionPercent(platformSettings.getCommissionPercent())
                .totalOwed(owed)
                .dueDate(dueDateOf(all))
                .entries(all.stream().map(this::toLedgerEntryDto).toList())
                .build()));
    }

    @PostMapping("/admin/settlements/provider/{providerId}/confirm-payout")
    @PreAuthorize(Perms.FINANCE)
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementDetailDto>> confirmPayout(
            @PathVariable Long providerId) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        List<CommissionLedgerEntry> outstanding = ledgerRepo.findByProviderIdAndStatusIn(providerId, OUTSTANDING);
        if (outstanding.isEmpty()) {
            throw new com.aiwa.exception.BusinessException("No outstanding balance for this provider");
        }
        LocalDateTime now = LocalDateTime.now();
        outstanding.forEach(e -> { e.setStatus(LedgerEntryStatus.SETTLED); e.setSettledAt(now); });
        ledgerRepo.saveAll(outstanding);
        provider.setSettlementPaused(false);
        provider.setSettlementReportedAt(null);
        providerRepo.save(provider);
        auditService.record("SETTLEMENT_CONFIRMED", provider.getBusinessName() + " · " + outstanding.size() + " entries");
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_CONFIRMED,
                "Settlement confirmed", "تم تأكيد التسوية",
                "AIWA confirmed your commission payout — your account is in good standing.",
                "أكدت AIWA دفع عمولتك — حسابك في وضع جيد.",
                null, provider.getId());
        return providerDetail(providerId);
    }

    @GetMapping(value = "/admin/settlements/export", produces = "text/csv")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<String> exportLedger() {
        StringBuilder csv = new StringBuilder("id,providerId,bookingId,bookingAmount,commissionPercent,commissionAmount,status,createdAt,settledAt\n");
        ledgerRepo.findAllByOrderByCreatedAtDesc().forEach(e -> csv
                .append(e.getId()).append(',')
                .append(e.getProvider().getId()).append(',')
                .append(e.getBooking() != null ? e.getBooking().getId() : "").append(',')
                .append(e.getBookingAmount()).append(',')
                .append(e.getCommissionPercent()).append(',')
                .append(e.getCommissionAmount()).append(',')
                .append(e.getStatus()).append(',')
                .append(e.getCreatedAt() != null ? e.getCreatedAt() : "").append(',')
                .append(e.getSettledAt() != null ? e.getSettledAt() : "").append('\n'));
        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"commission-ledger.csv\"")
                .body(csv.toString());
    }

    @PostMapping("/admin/settlements/provider/{providerId}/remind")
    @PreAuthorize(Perms.FINANCE)
    public ResponseEntity<ApiResponse.Success<Void>> sendOverdueReminder(@PathVariable Long providerId) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        BigDecimal due = ledgerRepo.sumByProviderAndStatus(providerId, LedgerEntryStatus.DUE);
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_OVERDUE,
                "Settlement reminder", "تذكير بالتسوية",
                "You have an outstanding commission balance of " + (due != null ? due : BigDecimal.ZERO)
                        + ". Please settle to keep receiving bookings.",
                "لديك رصيد عمولة مستحق قدره " + (due != null ? due : BigDecimal.ZERO)
                        + ". يرجى التسوية للاستمرار في استقبال الحجوزات.",
                null, provider.getId());
        return ResponseEntity.ok(ApiResponse.Success.of("Reminder sent", null));
    }

    @PatchMapping("/admin/settlements/{id}/settle")
    @PreAuthorize(Perms.FINANCE)
    public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionLedgerDto>> settle(@PathVariable Long id) {
        CommissionLedgerEntry entry = ledgerRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ledger entry", id));
        entry.setStatus(LedgerEntryStatus.SETTLED);
        entry.setSettledAt(LocalDateTime.now());
        CommissionLedgerEntry saved = ledgerRepo.save(entry);
        ProviderProfile provider = entry.getProvider();
        // Settling one entry lifts the pause only when nothing overdue remains and
        // the balance is back under the limit (before, any single entry un-paused).
        if (settlementService.mayResumeBookings(provider)) {
            provider.setSettlementPaused(false);
            provider.setSettlementReportedAt(null);
        }
        providerRepo.save(provider);
        auditService.record("SETTLEMENT_CONFIRMED", "ledger #" + entry.getId());
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_CONFIRMED,
                "Settlement confirmed", "تم تأكيد التسوية",
                "Settlement was confirmed for ledger entry #" + entry.getId(),
                "تم تأكيد التسوية للمعاملة رقم " + entry.getId(),
                entry.getBooking() != null ? entry.getBooking().getId() : null, provider.getId());
        return ResponseEntity.ok(ApiResponse.Success.of("Settlement confirmed", toDto(saved)));
    }

    @PatchMapping("/admin/providers/{providerId}/settlement-pause")
    @PreAuthorize(Perms.FINANCE)
    public ResponseEntity<ApiResponse.Success<Void>> setSettlementPause(
            @PathVariable Long providerId,
            @RequestParam boolean paused) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        provider.setSettlementPaused(paused);
        providerRepo.save(provider);
        auditService.record(paused ? "SETTLEMENT_PAUSED" : "SETTLEMENT_RESUMED", provider.getBusinessName());
        return ResponseEntity.ok(ApiResponse.Success.of("Settlement pause updated", null));
    }

    private ApiResponse.SettlementSummaryDto toSummary(ProviderProfile provider) {
        List<CommissionLedgerEntry> all = ledgerRepo.findByProviderIdOrderByCreatedAtDesc(provider.getId());
        BigDecimal due = sum(all, LedgerEntryStatus.DUE);
        BigDecimal overdue = sum(all, LedgerEntryStatus.OVERDUE);
        return ApiResponse.SettlementSummaryDto.builder()
                .providerId(provider.getId())
                // dueAmount is what the app shows as "owed": everything still
                // outstanding. It used to leave out OVERDUE entries, so a provider
                // who fell behind saw a smaller balance than they actually owed.
                .dueAmount(due.add(overdue))
                .overdueAmount(overdue)
                .owedAmount(due.add(overdue))
                .balanceLimit(settlementService.balanceLimit())
                .dueDate(dueDateOf(all))
                .status(statusOf(all))
                .paymentReportedAt(provider.getSettlementReportedAt())
                .settlementPaused(provider.isSettlementPaused())
                .entries(all.stream().map(this::toDto).toList())
                .build();
    }

    private static BigDecimal sum(List<CommissionLedgerEntry> entries, LedgerEntryStatus status) {
        return entries.stream().filter(e -> e.getStatus() == status)
                .map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // ── helpers for the admin Settlements screen ────────────────────────────

    private List<ApiResponse.SettlementRowDto> providerRows() {
        java.util.Map<Long, List<CommissionLedgerEntry>> byProvider = new java.util.LinkedHashMap<>();
        for (CommissionLedgerEntry e : ledgerRepo.findAllByOrderByCreatedAtDesc()) {
            byProvider.computeIfAbsent(e.getProvider().getId(), k -> new java.util.ArrayList<>()).add(e);
        }
        List<ApiResponse.SettlementRowDto> rows = new java.util.ArrayList<>();
        byProvider.forEach((providerId, entries) -> {
            ProviderProfile p = entries.get(0).getProvider();
            BigDecimal gross = entries.stream()
                    .filter(e -> OUTSTANDING.contains(e.getStatus()))
                    .map(CommissionLedgerEntry::getBookingAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal owed = entries.stream()
                    .filter(e -> OUTSTANDING.contains(e.getStatus()))
                    .map(CommissionLedgerEntry::getCommissionAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            rows.add(ApiResponse.SettlementRowDto.builder()
                    .providerId(providerId)
                    .providerName(p.getBusinessName())
                    .commissionPercent(platformSettings.getCommissionPercentFor(p))
                    .commissionOverridePercent(p.getCommissionOverridePercent())
                    .platformCommissionPercent(platformSettings.getCommissionPercent())
                    .grossAmount(gross)
                    .balanceOwed(owed)
                    .status(statusOf(entries))
                    .settlementPaused(p.isSettlementPaused())
                    .dueDate(dueDateOf(entries))
                    .build());
        });
        return rows;
    }

    private String statusOf(List<CommissionLedgerEntry> entries) {
        boolean overdue = entries.stream().anyMatch(e -> e.getStatus() == LedgerEntryStatus.OVERDUE);
        boolean anyDue = entries.stream().anyMatch(e -> OUTSTANDING.contains(e.getStatus()));
        if (overdue) return "OVERDUE";
        return anyDue ? "WITHIN_LIMIT" : "SETTLED";
    }

    /** Settlement due ~7 days after the oldest outstanding entry. */
    private LocalDateTime dueDateOf(List<CommissionLedgerEntry> entries) {
        return entries.stream()
                .filter(e -> OUTSTANDING.contains(e.getStatus()))
                .map(CommissionLedgerEntry::getCreatedAt)
                .filter(java.util.Objects::nonNull)
                .min(LocalDateTime::compareTo)
                .map(d -> d.plusDays(settlementService.dueDays()))
                .orElse(null);
    }

    private ApiResponse.LedgerEntryDto toLedgerEntryDto(CommissionLedgerEntry e) {
        Booking b = e.getBooking();
        return ApiResponse.LedgerEntryDto.builder()
                .id(e.getId())
                .serviceName(b != null && b.getService() != null ? b.getService().getName() : "Booking")
                .customerName(b != null && b.getCustomer() != null ? b.getCustomer().getFullName() : null)
                .bookingId(b != null ? b.getId() : null)
                .bookingAmount(e.getBookingAmount())
                .commissionPercent(e.getCommissionPercent())
                .commissionAmount(e.getCommissionAmount())
                .status(e.getStatus())
                .createdAt(e.getCreatedAt())
                .settledAt(e.getSettledAt())
                .build();
    }

    private ApiResponse.CommissionLedgerDto toDto(CommissionLedgerEntry e) {
        return ApiResponse.CommissionLedgerDto.builder()
                .id(e.getId())
                .providerId(e.getProvider().getId())
                .bookingId(e.getBooking() != null ? e.getBooking().getId() : null)
                .bookingAmount(e.getBookingAmount())
                .commissionPercent(e.getCommissionPercent())
                .commissionAmount(e.getCommissionAmount())
                .status(e.getStatus())
                .createdAt(e.getCreatedAt())
                .settledAt(e.getSettledAt())
                .build();
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
