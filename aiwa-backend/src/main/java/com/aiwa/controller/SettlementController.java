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
     *
     * <p>CR-06: the report freezes what it covers. Every entry outstanding now is
     * stamped with the report time, and a second report while this one waits is
     * refused, so commission recorded later can never ride along with it.</p>
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
            throw new com.aiwa.exception.BusinessException("settlement.error.nothing_to_settle");
        }
        if (provider.getSettlementReportedAt() != null
                && outstanding.stream().anyMatch(e -> e.getPayoutReportedAt() != null)) {
            throw new com.aiwa.exception.BusinessException("settlement.error.report_pending");
        }
        BigDecimal owed = sum(outstanding);

        LocalDateTime now = LocalDateTime.now();
        // Managed entities in this transaction: the stamp is written at commit.
        outstanding.forEach(e -> e.setPayoutReportedAt(now));
        provider.setSettlementReportedAt(now);
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
    @PreAuthorize(Perms.FINANCE_READ)
    public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.CommissionLedgerDto>>> dueEntries(
            @RequestParam(defaultValue = "DUE") LedgerEntryStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "200") int size) {
        // DR-028: paged; the admin panel walks the pages.
        return ResponseEntity.ok(ApiResponse.Success.of(ledgerRepo
                .findByStatusOrderByCreatedAtAsc(status, com.aiwa.util.Pages.admin(page, size))
                .map(this::toDto)));
    }

    // ── Admin Settlements screen: overview cards + per-provider rows ──────────

    @GetMapping("/admin/settlements/overview")
    @PreAuthorize(Perms.FINANCE_READ)
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementOverviewDto>> overview() {
        // DR-028: totals computed in the database, not by loading the whole ledger.
        BigDecimal totalOwed = ledgerRepo.sumByStatusIn(OUTSTANDING);
        int owing = (int) ledgerRepo.countDistinctProvidersByStatusIn(OUTSTANDING);
        return ResponseEntity.ok(ApiResponse.Success.of(ApiResponse.SettlementOverviewDto.builder()
                .commissionPercent(platformSettings.getCommissionPercent())
                .totalOwed(totalOwed)
                .providerCount(owing)
                .build()));
    }

    @GetMapping("/admin/settlements/providers")
    @PreAuthorize(Perms.FINANCE_READ)
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.SettlementRowDto>>> providers(
            @RequestParam(required = false) String query,
            @RequestParam(defaultValue = "ALL") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "200") int size) {
        // R5 follow-up: searched (provider name) and filtered (settlement status) on the server, with the real total.
        String wanted = status == null ? "ALL" : status.trim().toUpperCase();
        if (!java.util.Set.of("ALL", "OVERDUE", "WITHIN_LIMIT", "SETTLED").contains(wanted)) {
            throw new com.aiwa.exception.BusinessException("Unknown status: " + status);
        }
        return ResponseEntity.ok(ApiResponse.Success.of(providerRows(
                com.aiwa.util.Searches.pattern(query), wanted, com.aiwa.util.Pages.admin(page, size))));
    }

    @GetMapping("/admin/settlements/provider/{providerId}")
    @PreAuthorize(Perms.FINANCE_READ)
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
                .settlementPaused(provider.isBookingPaused())
                .accountSuspended(provider.getVerificationStatus() == com.aiwa.enums.VerificationStatus.SUSPENDED)
                .status(statusOf(all))
                .paymentReportedAt(provider.getSettlementReportedAt())
                .commissionPercent(platformSettings.getCommissionPercentFor(provider))
                .commissionOverridePercent(provider.getCommissionOverridePercent())
                .platformCommissionPercent(platformSettings.getCommissionPercent())
                .totalOwed(owed)
                .dueDate(dueDateOf(all))
                .entries(all.stream().map(this::toLedgerEntryDto).toList())
                .build()));
    }

    /**
     * What a payout confirmation would settle right now: the entries frozen by
     * the provider's waiting "I paid" report, or every outstanding entry when
     * the provider has not reported (finance received the money another way).
     */
    private List<CommissionLedgerEntry> payoutEntries(ProviderProfile provider) {
        List<CommissionLedgerEntry> outstanding = ledgerRepo.findByProviderIdAndStatusIn(provider.getId(), OUTSTANDING);
        if (provider.getSettlementReportedAt() == null) return outstanding;
        return outstanding.stream().filter(e -> e.getPayoutReportedAt() != null).toList();
    }

    /** CR-06: the total the admin dialog shows and sends back as {@code expectedAmount}. */
    @GetMapping("/admin/settlements/provider/{providerId}/payout-report")
    @PreAuthorize(Perms.FINANCE)
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> payoutReport(@PathVariable Long providerId) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        List<CommissionLedgerEntry> entries = payoutEntries(provider);
        java.util.Map<String, Object> report = new java.util.HashMap<>();
        report.put("reportedAt", provider.getSettlementReportedAt());
        report.put("total", sum(entries));
        report.put("entryCount", entries.size());
        return ResponseEntity.ok(ApiResponse.Success.of(report));
    }

    /**
     * Finance confirms the money arrived. CR-06: the cut-off used to default to
     * the provider's report time, which every new report moved, and the amount
     * check was optional and never sent, so commission the provider had not paid
     * for could be settled. Now it settles only {@link #payoutEntries} (the
     * frozen report) and {@code expectedAmount} is required and must equal their
     * total. One transaction, and ledger rows are versioned, so the hourly sweep
     * can't overwrite it halfway.
     */
    @PostMapping("/admin/settlements/provider/{providerId}/confirm-payout")
    @PreAuthorize(Perms.FINANCE)
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementDetailDto>> confirmPayout(
            @PathVariable Long providerId,
            @RequestParam(required = false) BigDecimal expectedAmount) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        if (expectedAmount == null) {
            throw new com.aiwa.exception.BusinessException("settlement.error.amount_required");
        }
        List<CommissionLedgerEntry> outstanding = payoutEntries(provider);
        if (outstanding.isEmpty()) {
            throw new com.aiwa.exception.BusinessException("No outstanding balance for this provider");
        }
        BigDecimal total = sum(outstanding);
        if (total.compareTo(expectedAmount) != 0) {
            throw new com.aiwa.exception.BusinessException("settlement.error.amount_mismatch");
        }
        LocalDateTime now = LocalDateTime.now();
        outstanding.forEach(e -> { e.setStatus(LedgerEntryStatus.SETTLED); e.setSettledAt(now); });
        ledgerRepo.saveAll(outstanding);
        provider.setSettlementReportedAt(null);
        // Entries recorded after the report stay outstanding; lift the pause only
        // when what remains is within the rules.
        if (settlementService.mayResumeBookings(provider)) {
            provider.setSettlementPaused(false);
        }
        providerRepo.save(provider);
        auditService.record("SETTLEMENT_CONFIRMED", provider.getBusinessName() + " · " + outstanding.size()
                + " entries · EGP " + total);
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_CONFIRMED,
                "Settlement confirmed", "تم تأكيد التسوية",
                "AIWA confirmed your commission payout — your account is in good standing.",
                "أكدت AIWA دفع عمولتك — حسابك في وضع جيد.",
                null, provider.getId());
        return providerDetail(providerId);
    }

    /** DR-028: streamed 500 rows at a time instead of building the whole ledger in memory. */
    @GetMapping(value = "/admin/settlements/export", produces = "text/csv")
    @PreAuthorize(Perms.FINANCE_READ)
    public ResponseEntity<org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody> exportLedger() {
        org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody body = out -> {
            var w = new java.io.BufferedWriter(new java.io.OutputStreamWriter(out, java.nio.charset.StandardCharsets.UTF_8));
            w.write("id,providerId,bookingId,bookingAmount,commissionPercent,commissionAmount,status,createdAt,settledAt\n");
            long below = Long.MAX_VALUE;
            while (true) {
                var slice = ledgerRepo.findTop500ByIdLessThanOrderByIdDesc(below);
                if (slice.isEmpty()) break;
                for (CommissionLedgerEntry e : slice) {
                    w.write(e.getId() + "," + e.getProvider().getId() + ","
                            + (e.getBooking() != null ? e.getBooking().getId() : "") + ","
                            + e.getBookingAmount() + "," + e.getCommissionPercent() + ","
                            + e.getCommissionAmount() + "," + e.getStatus() + ","
                            + (e.getCreatedAt() != null ? e.getCreatedAt() : "") + ","
                            + (e.getSettledAt() != null ? e.getSettledAt() : "") + "\n");
                }
                below = slice.get(slice.size() - 1).getId();
            }
            w.flush();
        };
        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"commission-ledger.csv\"")
                .contentType(org.springframework.http.MediaType.parseMediaType("text/csv"))
                .body(body);
    }

    @PostMapping("/admin/settlements/provider/{providerId}/remind")
    @PreAuthorize(Perms.FINANCE)
    public ResponseEntity<ApiResponse.Success<Void>> sendOverdueReminder(@PathVariable Long providerId) {
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        // CR-07: DUE + OVERDUE. This summed DUE only, so a provider whose entries
        // were all overdue was reminded of a balance of 0.
        BigDecimal due = ledgerRepo.findByProviderIdAndStatusIn(providerId, OUTSTANDING).stream()
                .map(CommissionLedgerEntry::getCommissionAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        notificationService.send(provider.getUser().getId(), NotificationType.SETTLEMENT_OVERDUE,
                "Settlement reminder", "تذكير بالتسوية",
                "You have an outstanding commission balance of " + due
                        + ". Please settle to keep receiving bookings.",
                "لديك رصيد عمولة مستحق قدره " + due
                        + ". يرجى التسوية للاستمرار في استقبال الحجوزات.",
                null, provider.getId());
        return ResponseEntity.ok(ApiResponse.Success.of("Reminder sent", null));
    }

    @PatchMapping("/admin/settlements/{id}/settle")
    @PreAuthorize(Perms.FINANCE)
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionLedgerDto>> settle(
            @PathVariable Long id,
            @RequestParam(required = false) BigDecimal expectedAmount,
            @RequestParam(required = false) String reference) {
        CommissionLedgerEntry entry = ledgerRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ledger entry", id));
        // F-06: one FINANCE click must not forgive commission. The amount received and the payment
        // reference (bank transfer / wallet receipt) are required, like confirm-payout's expectedAmount.
        if (expectedAmount == null) {
            throw new com.aiwa.exception.BusinessException("settlement.error.amount_required");
        }
        if (reference == null || reference.isBlank() || reference.trim().length() > 100) {
            throw new com.aiwa.exception.BusinessException("A payment reference (1-100 characters) is required");
        }
        if (!OUTSTANDING.contains(entry.getStatus())) {
            throw new com.aiwa.exception.BusinessException("settlement.error.not_outstanding");
        }
        if (entry.getCommissionAmount().compareTo(expectedAmount) != 0) {
            throw new com.aiwa.exception.BusinessException("settlement.error.amount_mismatch");
        }
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
        auditService.record("SETTLEMENT_CONFIRMED", "ledger #" + entry.getId() + " · EGP " + expectedAmount + " · ref " + reference.trim());
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
        // SA-08: an admin lifting the pause is also the review that ends a disciplinary hold.
        if (!paused) provider.setDisciplinaryHold(false);
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
                .commissionPercent(platformSettings.getCommissionPercentFor(provider))
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
                .settlementPaused(provider.isBookingPaused())
                .entries(all.stream().map(this::toDto).toList())
                .build();
    }

    private static BigDecimal sum(List<CommissionLedgerEntry> entries) {
        return entries.stream().map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal sum(List<CommissionLedgerEntry> entries, LedgerEntryStatus status) {
        return entries.stream().filter(e -> e.getStatus() == status)
                .map(CommissionLedgerEntry::getCommissionAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // ── helpers for the admin Settlements screen ────────────────────────────

    /**
     * One row per provider with ledger entries, totals summed in the database
     * one page at a time (DR-028: this used to load the whole ledger).
     */
    private org.springframework.data.domain.Page<ApiResponse.SettlementRowDto> providerRows(
            String q, String status, org.springframework.data.domain.Pageable pageable) {
        var totals = ledgerRepo.searchProviderTotals(q, status, pageable);
        java.util.Map<Long, ProviderProfile> providers = new java.util.HashMap<>();
        providerRepo.findAllById(totals.map(t -> (Long) t[0]).toList())
                .forEach(p -> providers.put(p.getId(), p));
        List<ApiResponse.SettlementRowDto> rows = new java.util.ArrayList<>();
        for (Object[] t : totals) {
            Long providerId = (Long) t[0];
            ProviderProfile p = providers.get(providerId);
            if (p == null) continue;
            BigDecimal gross = t[1] == null ? BigDecimal.ZERO : new BigDecimal(t[1].toString());
            BigDecimal owed = t[2] == null ? BigDecimal.ZERO : new BigDecimal(t[2].toString());
            long overdue = t[3] == null ? 0 : ((Number) t[3]).longValue();
            long outstanding = t[4] == null ? 0 : ((Number) t[4]).longValue();
            LocalDateTime oldest = (LocalDateTime) t[5];
            rows.add(ApiResponse.SettlementRowDto.builder()
                    .providerId(providerId)
                    .providerName(p.getBusinessName())
                    .commissionPercent(platformSettings.getCommissionPercentFor(p))
                    .commissionOverridePercent(p.getCommissionOverridePercent())
                    .platformCommissionPercent(platformSettings.getCommissionPercent())
                    .grossAmount(gross)
                    .balanceOwed(owed)
                    .status(overdue > 0 ? "OVERDUE" : outstanding > 0 ? "WITHIN_LIMIT" : "SETTLED")
                    .settlementPaused(p.isBookingPaused())
                    .accountSuspended(p.getVerificationStatus() == com.aiwa.enums.VerificationStatus.SUSPENDED)
                    .dueDate(oldest == null ? null : oldest.plusDays(settlementService.dueDays()))
                    .paymentReportedAt(p.getSettlementReportedAt())
                    .build());
        }
        return new org.springframework.data.domain.PageImpl<>(rows, pageable, totals.getTotalElements());
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
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }
}
