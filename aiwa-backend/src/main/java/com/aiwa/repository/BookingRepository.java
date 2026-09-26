package com.aiwa.repository;

import com.aiwa.entity.Booking;
import com.aiwa.enums.BookingStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long> {

    Page<Booking> findByCustomerIdOrderByCreatedAtDesc(Long customerId, Pageable pageable);

    Page<Booking> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Page<Booking> findByStatusOrderByCreatedAtDesc(BookingStatus status, Pageable pageable);

    Page<Booking> findByProviderIdOrderByBookingDateAscStartTimeAsc(Long providerId, Pageable pageable);

    List<Booking> findByProviderIdAndBookingDate(Long providerId, LocalDate date);

    List<Booking> findByStaffMemberIdAndBookingDate(Long staffMemberId, LocalDate date);

    /** Conflict check scoped to a single staff member's calendar. */
    @Query("""
        SELECT COUNT(b) > 0 FROM Booking b
        WHERE b.staffMember.id = :staffId
          AND b.bookingDate = :date
          AND b.status NOT IN (
              com.aiwa.enums.BookingStatus.CANCELLED,
              com.aiwa.enums.BookingStatus.REJECTED,
              com.aiwa.enums.BookingStatus.EXPIRED)
          AND b.startTime < :endTime
          AND b.endTime > :startTime
        """)
    boolean existsConflictForStaff(@Param("staffId") Long staffId,
                                   @Param("date") LocalDate date,
                                   @Param("startTime") LocalTime startTime,
                                   @Param("endTime") LocalTime endTime);

    List<Booking> findByCustomerIdAndStatus(Long customerId, BookingStatus status);

    /** Check for conflicting slots on the same provider/date (ignoring slot-releasing states) */
    @Query("""
        SELECT COUNT(b) > 0 FROM Booking b
        WHERE b.provider.id = :providerId
          AND b.bookingDate = :date
          AND b.status NOT IN (
              com.aiwa.enums.BookingStatus.CANCELLED,
              com.aiwa.enums.BookingStatus.REJECTED,
              com.aiwa.enums.BookingStatus.EXPIRED)
          AND b.startTime < :endTime
          AND b.endTime > :startTime
        """)
    boolean existsConflict(@Param("providerId") Long providerId,
                           @Param("date") LocalDate date,
                           @Param("startTime") LocalTime startTime,
                           @Param("endTime") LocalTime endTime);

    /** Gap: PENDING requests created before the cutoff that the provider never answered. */
    List<Booking> findByStatusAndCreatedAtBefore(BookingStatus status, java.time.LocalDateTime cutoff);

    /** All bookings in one status — used by the expiry sweep, which applies a per-provider window. */
    List<Booking> findByStatus(BookingStatus status);

    @Query("SELECT COUNT(b) FROM Booking b WHERE b.provider.id = :providerId AND b.status = :status")
    long countByProviderAndStatus(@Param("providerId") Long providerId, @Param("status") BookingStatus status);

    long countByStatus(BookingStatus status);
    long countByCustomerId(Long customerId);
    long countByProviderId(Long providerId);
    long countByPaymentStatus(com.aiwa.enums.PaymentStatus paymentStatus);

    /** Used by the admin inbox — bookings currently in dispute need admin attention. */
    List<Booking> findByPaymentStatusOrderByCreatedAtDesc(com.aiwa.enums.PaymentStatus paymentStatus);

    Page<Booking> findByProviderIdOrderByCreatedAtDesc(Long providerId, Pageable pageable);

    @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.status = :status")
    java.math.BigDecimal sumRevenueByStatus(@Param("status") BookingStatus status);

    /** Daily booking counts by status, for the dashboard chart. Returns [bookingDate, status, count]. */
    @Query("""
        SELECT b.bookingDate, b.status, COUNT(b) FROM Booking b
        WHERE b.bookingDate >= :from
        GROUP BY b.bookingDate, b.status
        """)
    List<Object[]> countByDateAndStatus(@Param("from") LocalDate from);

    /** Gap 9: Find ACCEPTED bookings today whose startTime falls in the reminder window */
    @Query("""
        SELECT b FROM Booking b
        WHERE b.bookingDate = :date
          AND b.status = com.aiwa.enums.BookingStatus.ACCEPTED
          AND b.startTime >= :from
          AND b.startTime < :to
        """)
    List<Booking> findUpcomingForReminder(@Param("date") java.time.LocalDate date,
                                           @Param("from") LocalTime from,
                                           @Param("to") LocalTime to);
}

