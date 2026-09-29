package com.aiwa.config;

import com.aiwa.entity.*;
import com.aiwa.entity.Service;
import com.aiwa.enums.*;
import com.aiwa.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

/**
 * Populates the H2 database with realistic demo data whenever the `local`
 * profile is active. Idempotent: skips if any non-admin user already exists.
 */
@Slf4j
@Component
@Profile("local")
@Order(100) // after AdminBootstrapConfig
@RequiredArgsConstructor
public class LocalDataSeeder implements ApplicationRunner {

    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;
    private final ServiceRepository serviceRepo;
    private final BookingRepository bookingRepo;
    private final ChatMessageRepository chatRepo;
    private final StaffMemberRepository staffRepo;
    private final ReviewRepository reviewRepo;
    private final ComplaintRepository complaintRepo;
    private final ModerationCaseRepository moderationRepo;
    private final CommissionLedgerRepository ledgerRepo;
    private final SupportSettingsRepository supportRepo;
    private final TermsPolicyRepository termsRepo;
    private final AvailabilityRepository availabilityRepo;
    private final GalleryImageRepository galleryRepo;
    private final TrustedContactRepository trustedContactRepo;
    private final SafetyEventRepository safetyRepo;
    private final PasswordEncoder encoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        writeDemoDocuments();
        if (userRepo.countByRole(UserRole.CUSTOMER) > 0) {
            return;
        }
        log.info("[local] seeding demo data…");

        // ── Admins (primary + extras with different permission sets) ──────────
        admin("S. Mahmoud", "admin@aiwa.com", EnumSet.allOf(AdminPermission.class));
        admin("Mona Farouk", "mona@aiwa.com", EnumSet.of(AdminPermission.SUPER_ADMIN));
        admin("Yasmin Nabil", "yasmin@aiwa.com", EnumSet.of(AdminPermission.SUPPORT, AdminPermission.FINANCE));
        admin("Tarek Adel", "tarek@aiwa.com", EnumSet.of(AdminPermission.SUPPORT));

        // ── Customers ────────────────────────────────────────────────────────
        User layla = customer("Layla Hassan", "layla@example.com", "+201000000001");
        User karim = customer("Karim Helmi", "karim@example.com", "+201000000002");
        User yara  = customer("Yara Aboud", "yara@example.com", "+201000000003");
        User hana  = customer("Hana Kamal", "hana@example.com", "+201000000004");
        User dalia = customer("Dalia Saad", "dalia@example.com", "+201000000005");
        User nour  = customer("Nour Hassan", "nour@example.com", "+201000000006");

        // ── Providers (mix of verification states) ────────────────────────────
        ProviderProfile nadia = provider("Nadia Studio", "nadia.studio@aiwa.com", ServiceCategory.HAIR,
                VerificationStatus.APPROVED, "New Cairo", 30.0300, 31.4700, 4.8, 312, false);
        nadia.setProviderType(ProviderType.SHOP);
        providerRepo.save(nadia);
        staffMember(nadia, "Salma Adel", "Senior Stylist", "+201007770001", "Balayage, Color correction", true);
        staffMember(nadia, "Rania Fathy", "Stylist", "+201007770002", "Haircuts, Blowouts", true);
        staffMember(nadia, "Dina Kamal", "Junior Stylist", "+201007770003", "Haircuts", false);
        ProviderProfile layalaP = provider("Layla Beauty", "layla.beauty@aiwa.com", ServiceCategory.NAILS,
                VerificationStatus.APPROVED, "Zamalek", 30.0600, 31.2200, 4.6, 128, false);
        ProviderProfile maadi = provider("Maadi Hammam", "maadi.hammam@aiwa.com", ServiceCategory.SPA,
                VerificationStatus.APPROVED, "Maadi", 29.9600, 31.2500, 4.9, 87, true); // settlement paused
        ProviderProfile omar = provider("Omar — Barber", "omar.barber@aiwa.com", ServiceCategory.HAIR,
                VerificationStatus.PENDING_VERIFICATION, "Maadi", 29.9620, 31.2590, 0.0, 0, false);
        ProviderProfile hala = provider("Hala Skin Studio", "hala.skin@aiwa.com", ServiceCategory.SKIN,
                VerificationStatus.PENDING_VERIFICATION, "Heliopolis", 30.0880, 31.3220, 0.0, 0, false);
        ProviderProfile yousef = provider("Yousef Beauty", "yousef.beauty@aiwa.com", ServiceCategory.MAKEUP,
                VerificationStatus.SUSPENDED, "Nasr City", 30.0500, 31.3600, 3.4, 12, false);
        provider("Mariam Lashes", "mariam.lashes@aiwa.com", ServiceCategory.LASHES,
                VerificationStatus.REJECTED, "Dokki", 30.0380, 31.2110, 0.0, 0, false);

        // ── Per-provider overrides (demo) ───────────────────────────────────
        // Nadia negotiated a lower take rate; Maadi is on a higher one and a tighter response window.
        nadia.setCommissionOverridePercent(new BigDecimal("8.00"));
        layalaP.setResponseWindowMinutesOverride(180L);
        maadi.setCommissionOverridePercent(new BigDecimal("12.50"));
        maadi.setCancellationCutoffHoursOverride(4);
        maadi.setResponseWindowMinutesOverride(45L);
        // Layla travels to customers for home service — flat 150 EGP travel fee.
        layalaP.setHomeServiceTravelFee(new BigDecimal("150.00"));
        providerRepo.saveAll(java.util.List.of(nadia, layalaP, maadi));

        // ── Services for the approved providers ──────────────────────────────
        Service balayage = service(nadia, "Balayage", ServiceCategory.HAIR, "1100", 150);
        Service haircut  = service(nadia, "Haircut & Style", ServiceCategory.HAIR, "350", 60);
        Service gelMani   = service(layalaP, "Gel Manicure", ServiceCategory.NAILS, "180", 45);
        Service pedicure  = service(layalaP, "Classic Pedicure", ServiceCategory.NAILS, "220", 60);
        Service deepTissue = service(maadi, "Deep Tissue Massage", ServiceCategory.SPA, "450", 90);

        // ── Working hours (scheduled bookings must fall inside them) ─────────
        for (ProviderProfile p : java.util.List.of(nadia, layalaP, maadi)) {
            for (java.time.DayOfWeek d : java.time.DayOfWeek.values()) {
                availabilityRepo.save(Availability.builder()
                        .provider(p).dayOfWeek(d)
                        .startTime(LocalTime.of(9, 0)).endTime(LocalTime.of(22, 0))
                        .slotDurationMinutes(30)
                        .available(d != java.time.DayOfWeek.FRIDAY)
                        .build());
            }
        }

        // ── Gallery photos (one reported below, for Photo moderation) ───────
        GalleryImage nadiaPhoto = galleryRepo.save(GalleryImage.builder()
                .provider(nadia).url("/files/public/gallery/demo-salon.jpg").build());
        GalleryImage maadiPhoto = galleryRepo.save(GalleryImage.builder()
                .provider(maadi).url("/files/public/gallery/demo-venue.jpg").build());

        // ── Bookings across the whole lifecycle ──────────────────────────────
        LocalDate today = LocalDate.now();

        Booking live = booking(hana, nadia, balayage, today, LocalTime.of(16, 0), BookingStatus.IN_PROGRESS,
                PaymentStatus.CASH_PENDING, "1100", null, false, true);
        safetyRepo.save(SafetyEvent.builder()
                .booking(live).actor(hana).type(SafetyEventType.SOS)
                .latitude(30.0300).longitude(31.4700)
                .notes("Demo SOS — the provider asked me to go somewhere else")
                .build());

        Booking b1 = booking(nour, nadia, haircut, today, LocalTime.of(18, 0), BookingStatus.COMPLETED,
                PaymentStatus.CASH_CONFIRMED, "350", "35", false, false);
        Booking b2 = booking(yara, layalaP, gelMani, today, LocalTime.of(14, 30), BookingStatus.COMPLETED,
                PaymentStatus.CASH_CONFIRMED, "180", "18", false, false);

        // a live payment dispute — open in the Bookings monitor
        Booking disputed = booking(dalia, maadi, deepTissue, today, LocalTime.of(11, 0), BookingStatus.COMPLETED,
                PaymentStatus.DISPUTED, "450", null, false, true);

        booking(karim, nadia, haircut, today, LocalTime.of(13, 0), BookingStatus.CANCELLED,
                PaymentStatus.UNPAID, "350", null, true, false);
        booking(layla, layalaP, pedicure, today.minusDays(1), LocalTime.of(12, 0), BookingStatus.NO_SHOW,
                PaymentStatus.UNPAID, "220", null, true, false);
        booking(karim, nadia, haircut, today.plusDays(1), LocalTime.of(10, 0), BookingStatus.PENDING,
                PaymentStatus.UNPAID, "350", null, false, false);
        booking(yara, nadia, balayage, today.plusDays(2), LocalTime.of(15, 0), BookingStatus.ACCEPTED,
                PaymentStatus.CASH_PENDING, "1100", null, false, false);
        booking(nour, maadi, deepTissue, today.minusDays(3), LocalTime.of(17, 0), BookingStatus.REJECTED,
                PaymentStatus.UNPAID, "450", null, false, true);
        booking(hana, layalaP, gelMani, today.minusDays(4), LocalTime.of(11, 30), BookingStatus.EXPIRED,
                PaymentStatus.UNPAID, "180", null, false, false);

        // ── Reviews (two-way; low ratings feed Reviews moderation) ───────────
        review(nour, nadia, b1, 5, "Great result and very clean setup.");
        review(yara, layalaP, b2, 4, "Nice work, ran a little late though.");
        review(karim, nadia, b1, 2, "Late arrival and poor communication.");
        review(dalia, maadi, disputed, 1, "Charged for a service I paid for in cash already.");

        // ── Complaints (one flagged → shows in Flags) ────────────────────────
        complaint(layla, nadia, null, "Service delivered late", ComplaintStatus.OPEN, false);
        complaint(yara, maadi, null, "Booking double-charged", ComplaintStatus.UNDER_REVIEW, true);
        complaint(karim, null, yousef.getUser(), "Rude / unsafe behaviour toward staff", ComplaintStatus.OPEN, true);
        complaint(nour, layalaP, null, "No-show by provider", ComplaintStatus.RESOLVED, false);

        // ── Moderation queue ────────────────────────────────────────────────
        moderation(ModerationTargetType.GALLERY_IMAGE, nadiaPhoto.getId(), "Reported: unrelated / low quality photo");
        moderation(ModerationTargetType.REVIEW, 3L, "Reported: abusive language toward provider");
        moderation(ModerationTargetType.GALLERY_IMAGE, maadiPhoto.getId(), "Reported: not the actual venue");

        // ── Safety: a trusted contact and one open SOS for the admin queue ──
        trustedContactRepo.save(TrustedContact.builder()
                .user(hana).name("Mona Kamal").phone("+201000000099").relationship("Sister").build());

        // ── Chat thread on b1 (one normal message, one reported) ─────────────
        chatMessage(nour, b1, "Hi, are you still on for 6pm?");
        chatMessage(nadia.getUser(), b1, "Yes! Also, it's cheaper if you pay me directly outside the app.");
        ChatMessage reportedMessage = chatMessage(nadia.getUser(), b1, "Here's my personal number, message me there instead.");
        moderation(ModerationTargetType.CHAT_MESSAGE, reportedMessage.getId(), "Reported: asking to move payment off-platform");

        // ── Demo push token — proves the delivery path end-to-end (dev-log logs it) ──
        nour.setPushToken("demo-fcm-token-nour");
        nour.setPushPlatform(DevicePlatform.ANDROID);
        userRepo.save(nour);

        // ── Commission ledger (DUE / OVERDUE / SETTLED) ─────────────────────
        ledger(nadia, b1, "350", "35", LedgerEntryStatus.DUE, null);
        ledger(layalaP, b2, "180", "18", LedgerEntryStatus.DUE, null);
        ledger(maadi, disputed, "450", "45", LedgerEntryStatus.OVERDUE, null);
        ledger(nadia, b1, "1100", "110", LedgerEntryStatus.SETTLED, LocalDateTime.now().minusDays(6));

        // ── Support settings + published terms ──────────────────────────────
        if (supportRepo.count() == 0) {
            supportRepo.save(SupportSettings.builder()
                    .whatsappNumber("+201005550000")
                    .whatsappNumberDisplay("+20 100 555 0000")
                    .supportEmail("support@aiwa.com")
                    .availabilityHoursEn("Daily · 9:00 AM – 11:00 PM")
                    .whatsappEnabled(true)
                    .numbers(new java.util.ArrayList<>(java.util.List.of(
                            com.aiwa.entity.SupportNumber.builder()
                                    .label("General").number("+201005550000")
                                    .displayNumber("+20 100 555 0000").primary(true).enabled(true).build(),
                            com.aiwa.entity.SupportNumber.builder()
                                    .label("Payments & settlements").number("+201005550100")
                                    .displayNumber("+20 100 555 0100").primary(false).enabled(true).build(),
                            com.aiwa.entity.SupportNumber.builder()
                                    .label("Alexandria line").number("+201005550200")
                                    .displayNumber("+20 100 555 0200").primary(false).enabled(false).build())))
                    .build());
        }
        if (termsRepo.count() == 0) {
            termsRepo.save(TermsPolicy.builder().version("1.0.0").type("CUSTOMER_TERMS")
                    .contentEn("Initial launch terms — AIWA connects customers with verified beauty & grooming providers across Egypt.")
                    .active(false).build());
            termsRepo.save(TermsPolicy.builder().version("1.0.2").type("CUSTOMER_TERMS")
                    .contentEn("Clarified no-show handling and cash-payment confirmation.")
                    .active(false).build());
            termsRepo.save(TermsPolicy.builder().version("1.1.0").type("CUSTOMER_TERMS")
                    .contentEn("AIWA connects customers with verified beauty and grooming providers across Egypt. "
                            + "By using AIWA you agree to the booking, cancellation, home-service safety and cash-payment "
                            + "terms set out below, including provider cancel penalties and platform commission on cash bookings.")
                    .active(true).build());
            termsRepo.save(TermsPolicy.builder().version("1.0").type("PROVIDER_TERMS")
                    .contentEn("Providers agree to identity verification, to honour booked prices, to settle platform "
                            + "commission by its due date (overdue balances pause new bookings) and to keep customer "
                            + "details confidential.")
                    .active(true).build());
        }

        log.info("[local] demo data seeded: {} customers, {} providers, {} bookings",
                userRepo.countByRole(UserRole.CUSTOMER), providerRepo.count(), bookingRepo.count());
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    private User admin(String name, String email, EnumSet<AdminPermission> perms) {
        if (userRepo.existsByEmail(email)) return userRepo.findByEmail(email).orElseThrow();
        return userRepo.save(User.builder()
                .fullName(name).email(email).password(encoder.encode("AdminPassword123!"))
                .role(UserRole.ADMIN).preferredLanguage(Language.EN).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms))
                .build());
    }

    private User customer(String name, String email, String phone) {
        return userRepo.save(User.builder()
                .fullName(name).email(email).phone(phone).password(encoder.encode("password123"))
                .role(UserRole.CUSTOMER).gender(Gender.FEMALE).preferredLanguage(Language.EN)
                .active(true).termsAccepted(true).acceptedTermsVersion("1.1.0")
                .build());
    }

    /** Generates placeholder ID/selfie images so the admin document viewer has something to show. */
    private void writeDemoDocuments() {
        try {
            record Doc(String path, String caption, java.awt.Color bg) {}
            java.util.List<Doc> docs = java.util.List.of(
                    new Doc("uploads/private/national-id/demo-front.jpg", "NATIONAL ID · FRONT", new java.awt.Color(0x2A, 0x13, 0x20)),
                    new Doc("uploads/private/national-id/demo-back.jpg", "NATIONAL ID · BACK", new java.awt.Color(0x3A, 0x1E, 0x2E)),
                    new Doc("uploads/private/selfie/demo-selfie.jpg", "LIVE SELFIE", new java.awt.Color(0x4A, 0x2A, 0x3A)),
                    // public gallery demo photos (served at /api/files/public/gallery/…)
                    new Doc("uploads/public/gallery/demo-salon.jpg", "SALON · DEMO PHOTO", new java.awt.Color(0x6B, 0x3A, 0x3A)),
                    new Doc("uploads/public/gallery/demo-venue.jpg", "VENUE · DEMO PHOTO", new java.awt.Color(0x2E, 0x2A, 0x26))
            );
            for (Doc d : docs) {
                java.io.File f = new java.io.File(d.path());
                if (f.exists()) continue;
                f.getParentFile().mkdirs();
                java.awt.image.BufferedImage img = new java.awt.image.BufferedImage(640, 400, java.awt.image.BufferedImage.TYPE_INT_RGB);
                java.awt.Graphics2D g = img.createGraphics();
                g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
                g.setColor(d.bg());
                g.fillRect(0, 0, 640, 400);
                g.setColor(new java.awt.Color(0xE7, 0xBA, 0xB6));
                g.drawRect(24, 24, 592, 352);
                g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 26));
                g.setColor(java.awt.Color.WHITE);
                g.drawString(d.caption(), 48, 120);
                g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 15));
                g.setColor(new java.awt.Color(0xE7, 0xBA, 0xB6));
                g.drawString("AIWA demo document — not a real ID", 48, 160);
                g.dispose();
                javax.imageio.ImageIO.write(img, "jpg", f);
            }
        } catch (Exception e) {
            log.warn("[local] could not write demo documents: {}", e.getMessage());
        }
    }

    private ProviderProfile provider(String biz, String email, ServiceCategory cat, VerificationStatus vs,
                                     String area, double lat, double lng, double rating, int reviews,
                                     boolean settlementPaused) {
        User u = userRepo.save(User.builder()
                .fullName(biz).email(email).phone("+2011" + (int) (Math.random() * 9000000 + 1000000))
                .password(encoder.encode("password123")).role(UserRole.PROVIDER)
                .gender(Gender.FEMALE).preferredLanguage(Language.EN).active(vs != VerificationStatus.SUSPENDED)
                .termsAccepted(true).build());
        return providerRepo.save(ProviderProfile.builder()
                .user(u).businessName(biz).bio(biz + " — trusted " + cat.name().toLowerCase() + " specialists.")
                .address(area + ", Cairo").latitude(lat).longitude(lng)
                .providerType(ProviderType.INDIVIDUAL).primaryCategory(cat)
                .averageRating(rating).totalReviews(reviews).travelBufferMinutes(30)
                .cancellationStrikes(0).settlementPaused(settlementPaused)
                .verificationStatus(vs)
                .verifiedAt(vs == VerificationStatus.APPROVED || vs == VerificationStatus.SUSPENDED
                        ? LocalDateTime.now().minusMonths(3) : null)
                .rejectionReason(vs == VerificationStatus.REJECTED ? "ID photo was unreadable — please resubmit." : null)
                .nationalIdFrontPath("uploads/private/national-id/demo-front.jpg")
                .nationalIdBackPath("uploads/private/national-id/demo-back.jpg")
                .selfiePath("uploads/private/selfie/demo-selfie.jpg")
                .build());
    }

    private Service service(ProviderProfile p, String name, ServiceCategory cat, String price, int minutes) {
        return serviceRepo.save(Service.builder()
                .provider(p).name(name).description(name + " by " + p.getBusinessName())
                .price(new BigDecimal(price)).durationMinutes(minutes).category(cat)
                .transportIncluded(false).active(true).build());
    }

    private Booking booking(User customer, ProviderProfile provider, Service svc, LocalDate date, LocalTime start,
                            BookingStatus status, PaymentStatus payment, String total, String commission,
                            boolean penalty, boolean homeService) {
        return bookingRepo.save(Booking.builder()
                .customer(customer).provider(provider).service(svc)
                .bookingDate(date).startTime(start).endTime(start.plusMinutes(svc.getDurationMinutes()))
                .bookingType(BookingType.SCHEDULED).status(status).paymentStatus(payment)
                .paymentMethod("CASH").homeService(homeService).penaltyApplied(penalty)
                .totalPrice(new BigDecimal(total))
                .commissionAmount(commission != null ? new BigDecimal(commission) : null)
                .cancelledBy(status == BookingStatus.CANCELLED ? "PROVIDER" : null)
                .cancellationReason(status == BookingStatus.CANCELLED ? "Provider unavailable" : null)
                .cancelledAt(status == BookingStatus.CANCELLED ? LocalDateTime.now().minusHours(3) : null)
                .rejectionReason(status == BookingStatus.REJECTED ? "Fully booked that day" : null)
                .build());
    }

    private void review(User user, ProviderProfile provider, Booking booking, int rating, String comment) {
        reviewRepo.save(Review.builder()
                .user(user).provider(provider).booking(booking)
                .direction(ReviewDirection.CUSTOMER_TO_PROVIDER)
                .rating(rating).comment(comment).build());
    }

    private void complaint(User reporter, ProviderProfile targetProvider, User targetUser,
                           String desc, ComplaintStatus status, boolean flagged) {
        complaintRepo.save(Complaint.builder()
                .reporter(reporter).targetProvider(targetProvider).targetUser(targetUser)
                .category(targetProvider != null ? "PROVIDER" : "SAFETY")
                .description(desc).status(status).flagged(flagged)
                .adminNotes(status == ComplaintStatus.RESOLVED ? "Refund issued, provider warned." : null)
                .build());
    }

    private void moderation(ModerationTargetType type, Long targetId, String reason) {
        moderationRepo.save(ModerationCase.builder()
                .targetType(type).targetId(targetId).reason(reason)
                .status(ModerationStatus.OPEN).build());
    }

    private void staffMember(ProviderProfile provider, String fullName, String title, String phone,
                             String skills, boolean active) {
        staffRepo.save(StaffMember.builder()
                .provider(provider).fullName(fullName).title(title).phone(phone).skills(skills).active(active).build());
    }

    private ChatMessage chatMessage(User sender, Booking booking, String text) {
        return chatRepo.save(ChatMessage.builder()
                .booking(booking).sender(sender).type(ChatMessageType.TEXT).message(text).build());
    }

    private void ledger(ProviderProfile provider, Booking booking, String amount, String commission,
                        LedgerEntryStatus status, LocalDateTime settledAt) {
        ledgerRepo.save(CommissionLedgerEntry.builder()
                .provider(provider).booking(booking)
                .bookingAmount(new BigDecimal(amount)).commissionPercent(new BigDecimal("10"))
                .commissionAmount(new BigDecimal(commission)).status(status).settledAt(settledAt)
                .build());
    }
}
