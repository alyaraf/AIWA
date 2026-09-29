package com.aiwa.service.impl;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.ProviderWaitlistEntry;
import com.aiwa.entity.User;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.repository.ProviderWaitlistRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * "Notify me when someone joins" — customers who found nobody for a category
 * are told once, when a matching provider is approved nearby.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WaitlistService {

    /** A provider this far from the customer's search point still counts as "near". */
    static final double MATCH_RADIUS_KM = 25.0;

    private final ProviderWaitlistRepository waitlistRepo;
    private final NotificationServiceImpl notificationService;

    /** Idempotent: a second tap while an alert is pending doesn't add a duplicate. */
    @Transactional
    public void join(User user, ServiceCategory category, Double latitude, Double longitude) {
        boolean already = category == null
                ? waitlistRepo.existsByUserIdAndCategoryIsNullAndNotifiedAtIsNull(user.getId())
                : waitlistRepo.existsByUserIdAndCategoryAndNotifiedAtIsNull(user.getId(), category);
        if (already) return;
        waitlistRepo.save(ProviderWaitlistEntry.builder()
                .user(user).category(category).latitude(latitude).longitude(longitude).build());
    }

    @Transactional
    public int notifyProviderJoined(ProviderProfile provider) {
        if (provider.getPrimaryCategory() == null) return 0;
        int sent = 0;
        LocalDateTime now = LocalDateTime.now();
        for (ProviderWaitlistEntry entry : waitlistRepo.findOpenFor(provider.getPrimaryCategory())) {
            if (!near(entry, provider)) continue;
            entry.setNotifiedAt(now);
            waitlistRepo.save(entry);
            notificationService.send(entry.getUser().getId(), NotificationType.PROVIDER_AVAILABLE,
                    "A new provider joined near you", "انضم مقدم خدمة جديد بالقرب منك",
                    provider.getBusinessName() + " is now taking bookings on AIWA.",
                    provider.getBusinessName() + " يستقبل الحجوزات الآن على AIWA.",
                    null, provider.getId());
            sent++;
        }
        if (sent > 0) log.info("Waitlist: notified {} customer(s) about provider #{}", sent, provider.getId());
        return sent;
    }

    private static boolean near(ProviderWaitlistEntry e, ProviderProfile p) {
        if (e.getLatitude() == null || e.getLongitude() == null
                || p.getLatitude() == null || p.getLongitude() == null) {
            return true; // no location on one side — category match is enough
        }
        return GeoUtils.distanceKm(e.getLatitude(), e.getLongitude(), p.getLatitude(), p.getLongitude())
                <= MATCH_RADIUS_KM;
    }
}
