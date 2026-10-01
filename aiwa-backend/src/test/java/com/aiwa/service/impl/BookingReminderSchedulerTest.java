package com.aiwa.service.impl;

import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.repository.BookingRepository;
import com.aiwa.util.AiwaTime;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * R2-06: reminders never went out on PostgreSQL (the job ran read-only and the
 * notification INSERT failed every run). Each booking is now reminded once,
 * whenever the job runs inside the 2-hour lead.
 */
class BookingReminderSchedulerTest {

    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final NotificationServiceImpl notifications = mock(NotificationServiceImpl.class);
    private final BookingReminderScheduler scheduler =
            new BookingReminderScheduler(bookingRepo, notifications, mock(RedisLockService.class));

    private static Booking booking(LocalDateTime startsAt, LocalDateTime createdAt) {
        User customer = User.builder().id(1L).fullName("Nour").build();
        User owner = User.builder().id(2L).fullName("Layla").build();
        Booking b = Booking.builder().id(9L).status(BookingStatus.ACCEPTED)
                .customer(customer)
                .provider(ProviderProfile.builder().id(3L).user(owner).build())
                .service(com.aiwa.entity.Service.builder().id(4L).name("Haircut").build())
                .bookingDate(startsAt.toLocalDate()).startTime(startsAt.toLocalTime())
                .endTime(startsAt.toLocalTime().plusMinutes(30))
                .build();
        b.setCreatedAt(createdAt);
        return b;
    }

    @Test
    void theJobRunsInAWritableTransaction() throws Exception {
        Transactional tx = BookingReminderScheduler.class.getMethod("sendReminders").getAnnotation(Transactional.class);
        assertThat(tx).isNotNull();
        assertThat(tx.readOnly()).isFalse();
    }

    @Test
    void remindsBothSidesOnceAndMarksTheBooking() {
        LocalDateTime now = AiwaTime.now();
        Booking soon = booking(now.plusMinutes(90), now.minusDays(1));
        when(bookingRepo.findByStatusInAndReminderSentAtIsNullAndBookingDateBetween(any(), any(), any()))
                .thenReturn(List.of(soon));

        assertThat(scheduler.sendReminderBatch()).isEqualTo(1);

        assertThat(soon.getReminderSentAt()).isNotNull();
        verify(bookingRepo).save(soon);
        verify(notifications).send(eq(1L), any(), any(), any(), any(), any(), eq(9L), eq(3L));
        verify(notifications).send(eq(2L), any(), any(), any(), any(), any(), eq(9L), eq(3L));
    }

    @Test
    void laterBookingsWaitAndLastMinuteBookingsAreNotReminded() {
        LocalDateTime now = AiwaTime.now();
        Booking later = booking(now.plusHours(5), now.minusDays(1));
        Booking justMade = booking(now.plusMinutes(40), now.minusMinutes(5));
        when(bookingRepo.findByStatusInAndReminderSentAtIsNullAndBookingDateBetween(any(), any(), any()))
                .thenReturn(List.of(later, justMade));

        assertThat(scheduler.sendReminderBatch()).isZero();

        assertThat(later.getReminderSentAt()).isNull();
        assertThat(justMade.getReminderSentAt()).isNotNull(); // settled, never reminded
        verifyNoInteractions(notifications);
    }
}
