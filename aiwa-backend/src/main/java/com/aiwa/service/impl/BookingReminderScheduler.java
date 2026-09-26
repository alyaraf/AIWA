package com.aiwa.service.impl;

import com.aiwa.entity.Booking;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.repository.BookingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.Duration;
import java.util.List;

/**
 * Gap 9: Sends booking reminder notifications 2 hours before appointment.
 * Runs every 15 minutes.
 */
@Slf4j
@Component
@Profile("!test")
@RequiredArgsConstructor
public class BookingReminderScheduler {

    private final BookingRepository bookingRepo;
    private final NotificationServiceImpl notificationService;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelay = 15 * 60 * 1000)   // every 15 min
    @Transactional(readOnly = true)
    public void sendReminders() {
        redisLockService.withLock("booking-reminders", Duration.ofMinutes(10), this::sendReminderBatch);
    }

    private void sendReminderBatch() {
        LocalDate today   = LocalDate.now();
        LocalTime now     = LocalTime.now();
        LocalTime in2h    = now.plusHours(2);
        LocalTime in2h15  = now.plusHours(2).plusMinutes(15); // window

        List<Booking> upcoming = bookingRepo.findUpcomingForReminder(today, in2h, in2h15);
        upcoming.forEach(booking -> {
            // Notify customer
            notificationService.send(
                    booking.getCustomer().getId(),
                    NotificationType.BOOKING_REMINDER,
                    "Reminder: Upcoming appointment",
                    "تذكير: موعد قادم",
                    "Your " + booking.getService().getName()
                            + " appointment is in approximately 2 hours at "
                            + booking.getStartTime(),
                    "موعدك لـ " + booking.getService().getName()
                            + " بعد ساعتين تقريباً في " + booking.getStartTime(),
                    booking.getId(), booking.getProvider().getId()
            );
            // Notify provider
            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.BOOKING_REMINDER,
                    "Reminder: Upcoming booking",
                    "تذكير: حجز قادم",
                    booking.getCustomer().getFullName()
                            + " has a " + booking.getService().getName()
                            + " appointment in ~2 hours",
                    "لدى " + booking.getCustomer().getFullName()
                            + " موعد لـ " + booking.getService().getName() + " بعد ساعتين",
                    booking.getId(), booking.getProvider().getId()
            );
            log.debug("Sent reminder for booking {}", booking.getId());
        });
    }
}
