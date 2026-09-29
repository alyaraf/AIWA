package com.aiwa.service.impl;

import com.aiwa.entity.PlatformSettings;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.PlatformSettingsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * Reads/writes the admin-editable commission rate. The DB row is the source of
 * truth; the {@code aiwa.commission.percent} property is only the seed default
 * used before an admin has set a value.
 */
@Service
@RequiredArgsConstructor
public class PlatformSettingsServiceImpl {

    private final PlatformSettingsRepository repo;

    @Value("${aiwa.commission.percent:10}")
    private BigDecimal defaultCommissionPercent;

    @Value("${aiwa.cancellation.cutoff-hours:2}")
    private int defaultCancellationCutoffHours;

    @Value("${aiwa.cancellation.provider-penalty-percent:15}")
    private BigDecimal defaultProviderCancelPenaltyPercent;

    @Value("${aiwa.booking.response-window-minutes:120}")
    private long defaultResponseWindowMinutes;

    @Transactional
    public PlatformSettings getOrCreate() {
        return repo.findFirstByOrderByIdAsc().orElseGet(() ->
                repo.save(PlatformSettings.builder()
                        .commissionPercent(defaultCommissionPercent)
                        .build()));
    }

    @Transactional(readOnly = true)
    public BigDecimal getCommissionPercent() {
        return repo.findFirstByOrderByIdAsc()
                .map(PlatformSettings::getCommissionPercent)
                .orElse(defaultCommissionPercent);
    }

    /** Effective commission for one provider: their override if set, else the platform rate. */
    @Transactional(readOnly = true)
    public BigDecimal getCommissionPercentFor(ProviderProfile provider) {
        if (provider != null && provider.getCommissionOverridePercent() != null) {
            return provider.getCommissionOverridePercent();
        }
        return getCommissionPercent();
    }

    // ── Booking rules (fall back to config defaults when unset) ──────────────

    @Transactional(readOnly = true)
    public int getCancellationCutoffHours() {
        Integer value = current().map(PlatformSettings::getCancellationCutoffHours).orElse(null);
        return value != null ? value : defaultCancellationCutoffHours;
    }

    @Transactional(readOnly = true)
    public BigDecimal getProviderCancelPenaltyPercent() {
        BigDecimal value = current().map(PlatformSettings::getProviderCancelPenaltyPercent).orElse(null);
        return value != null ? value : defaultProviderCancelPenaltyPercent;
    }

    @Transactional(readOnly = true)
    public long getResponseWindowMinutes() {
        Long value = current().map(PlatformSettings::getResponseWindowMinutes).orElse(null);
        return value != null ? value : defaultResponseWindowMinutes;
    }

    // ── Booking rules, resolved for one provider (override → platform → config) ──

    @Transactional(readOnly = true)
    public int getCancellationCutoffHours(ProviderProfile provider) {
        if (provider != null && provider.getCancellationCutoffHoursOverride() != null) {
            return provider.getCancellationCutoffHoursOverride();
        }
        return getCancellationCutoffHours();
    }

    @Transactional(readOnly = true)
    public BigDecimal getProviderCancelPenaltyPercent(ProviderProfile provider) {
        if (provider != null && provider.getProviderCancelPenaltyPercentOverride() != null) {
            return provider.getProviderCancelPenaltyPercentOverride();
        }
        return getProviderCancelPenaltyPercent();
    }

    @Transactional(readOnly = true)
    public long getResponseWindowMinutes(ProviderProfile provider) {
        if (provider != null && provider.getResponseWindowMinutesOverride() != null) {
            return provider.getResponseWindowMinutesOverride();
        }
        return getResponseWindowMinutes();
    }

    // ── Validation shared by platform + per-provider rule edits ─────────────────

    /** @throws BusinessException if any non-null value is outside its allowed range. */
    public void validateBookingRules(Integer cutoffHours, BigDecimal penaltyPercent, Long responseWindowMinutes) {
        if (cutoffHours != null && (cutoffHours < 0 || cutoffHours > 168))
            throw new BusinessException("Cancellation cutoff must be between 0 and 168 hours");
        if (penaltyPercent != null && (penaltyPercent.signum() < 0 || penaltyPercent.compareTo(BigDecimal.valueOf(100)) > 0))
            throw new BusinessException("Penalty percent must be between 0 and 100");
        if (responseWindowMinutes != null && (responseWindowMinutes < 1 || responseWindowMinutes > 1440))
            throw new BusinessException("Response window must be between 1 and 1440 minutes");
    }

    /** @throws BusinessException if the commission percent is null or outside 0–100. */
    public void validateCommissionPercent(BigDecimal percent) {
        if (percent == null || percent.signum() < 0 || percent.compareTo(BigDecimal.valueOf(100)) > 0) {
            throw new BusinessException("Commission percent must be between 0 and 100");
        }
    }

    private java.util.Optional<PlatformSettings> current() {
        return repo.findFirstByOrderByIdAsc();
    }

    @Transactional
    public PlatformSettings updateBookingRules(Integer cutoffHours, BigDecimal penaltyPercent, Long responseWindowMinutes) {
        validateBookingRules(cutoffHours, penaltyPercent, responseWindowMinutes);

        PlatformSettings settings = getOrCreate();
        if (cutoffHours != null) settings.setCancellationCutoffHours(cutoffHours);
        if (penaltyPercent != null) settings.setProviderCancelPenaltyPercent(penaltyPercent);
        if (responseWindowMinutes != null) settings.setResponseWindowMinutes(responseWindowMinutes);
        return repo.save(settings);
    }

    @Transactional
    public PlatformSettings updateCommissionPercent(BigDecimal percent) {
        // Platform rate: 0 < n ≤ 50 (kit rule). Per-provider overrides keep 0–100.
        if (percent == null || percent.signum() <= 0 || percent.compareTo(BigDecimal.valueOf(50)) > 0) {
            throw new BusinessException("Commission percent must be above 0 and at most 50");
        }
        PlatformSettings settings = getOrCreate();
        settings.setCommissionPercent(percent);
        return repo.save(settings);
    }
}
