package com.aiwa.service.impl;

import com.aiwa.entity.Booking;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.repository.BookingRepository;
import com.aiwa.util.AiwaTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.List;

/**
 * Sends one reminder to both sides about 2 hours before an accepted booking.
 *
 * <p>R2-06: this ran in a read-only transaction, so on PostgreSQL every run
 * failed at the first notification INSERT and no reminder was ever sent (H2 in
 * the tests ignored read-only). It also looked at a fixed 15-minute window that
 * drifted with the scheduler's fixed delay, missed bookings shortly after
 * midnight, and had no record of what was sent. Now each booking carries
 * {@code reminderSentAt}, and every run picks up whatever is due.</p>
 */
@Slf4j
@Component
@Profile("!test")
@RequiredArgsConstructor
public class BookingReminderScheduler {

    static final Duration LEAD = Duration.ofHours(2);

    private final BookingRepository bookingRepo;
    private final NotificationServiceImpl notificationService;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelay = 5 * 60 * 1000)   // every 5 min
    @Transactional
    public void sendReminders() {
        // Safe to run unlocked if Redis is down: reminderSentAt makes it send once.
        redisLockService.withLock("booking-reminders", Duration.ofMinutes(4), true, this::sendReminderBatch);
    }

    int sendReminderBatch() {
        LocalDateTime now = AiwaTime.now();
        LocalDateTime horizon = now.plus(LEAD);
        List<Booking> candidates = bookingRepo.findByStatusInAndReminderSentAtIsNullAndBookingDateBetween(
                EnumSet.of(BookingStatus.ACCEPTED), now.toLocalDate(), horizon.toLocalDate());
        int sent = 0;
        for (Booking booking : candidates) {
            LocalDateTime startsAt = LocalDateTime.of(booking.getBookingDate(), booking.getStartTime());
            if (startsAt.isBefore(now) || startsAt.isAfter(horizon)) continue;
            booking.setReminderSentAt(now);
            bookingRepo.save(booking);
            // A booking made less than 2 hours ahead needs no reminder.
            if (booking.getCreatedAt() != null && booking.getCreatedAt().isAfter(startsAt.minus(LEAD))) continue;
            remind(booking);
            sent++;
        }
        if (sent > 0) log.info("Sent {} booking reminder(s)", sent);
        return sent;
    }

    private void remind(Booking booking) {
        String service = booking.getService().getName();
        notificationService.send(
                booking.getCustomer().getId(),
                NotificationType.BOOKING_REMINDER,
                "Reminder: Upcoming appointment",
                "تذكير: موعد قادم",
                "Your " + service + " appointment is at " + booking.getStartTime() + " today.",
                "موعدك لـ " + service + " اليوم في " + booking.getStartTime(),
                booking.getId(), booking.getProvider().getId()
        );
        notificationService.send(
                booking.getProvider().getUser().getId(),
                NotificationType.BOOKING_REMINDER,
                "Reminder: Upcoming booking",
                "تذكير: حجز قادم",
                booking.getCustomer().getFullName() + " has a " + service + " appointment at "
                        + booking.getStartTime() + ".",
                "لدى " + booking.getCustomer().getFullName() + " موعد لـ " + service + " في "
                        + booking.getStartTime(),
                booking.getId(), booking.getProvider().getId()
        );
    }
}
