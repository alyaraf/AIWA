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


    /** Admin bookings monitor: status / dispute filter + free-text search, server-side paged.
     *  [pattern] is a lower-case LIKE pattern ("%" = no search). */
    @Query("""
            SELECT b FROM Booking b
            WHERE (:status IS NULL OR b.status = :status)
              AND (:disputed = false OR b.paymentStatus = com.aiwa.enums.PaymentStatus.DISPUTED)
              AND (:pattern = '%'
                   OR LOWER(b.customer.fullName) LIKE :pattern
                   OR LOWER(b.provider.businessName) LIKE :pattern
                   OR LOWER(b.service.name) LIKE :pattern
                   OR CAST(b.id AS String) LIKE :pattern)
            ORDER BY b.createdAt DESC
            """)
    Page<Booking> adminSearch(@Param("status") BookingStatus status,
                              @Param("disputed") boolean disputed,
                              @Param("pattern") String pattern,
                              Pageable pageable);

    long countByStatusIn(java.util.Collection<BookingStatus> statuses);

    long countByStatusInAndCreatedAtBetween(java.util.Collection<BookingStatus> statuses,
                                            java.time.LocalDateTime from, java.time.LocalDateTime to);

    Page<Booking> findByProviderIdOrderByBookingDateAscStartTimeAsc(Long providerId, Pageable pageable);

    // ── Status-filtered lists (BE-9: tabs must not filter a single page client-side) ──
    Page<Booking> findByCustomerIdAndStatusInOrderByCreatedAtDesc(
            Long customerId, java.util.Collection<BookingStatus> statuses, Pageable pageable);

    Page<Booking> findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc(
            Long providerId, java.util.Collection<BookingStatus> statuses, Pageable pageable);

    Page<Booking> findByProviderIdAndStatusInOrderByBookingDateDescStartTimeDesc(
            Long providerId, java.util.Collection<BookingStatus> statuses, Pageable pageable);

    Page<Booking> findByProviderIdOrderByBookingDateDescStartTimeDesc(Long providerId, Pageable pageable);

    /** Same slot check as {@link #existsConflict} but ignoring one booking (the one being moved). */
    @Query("""
        SELECT COUNT(b) > 0 FROM Booking b
        WHERE b.provider.id = :providerId
          AND b.id <> :excludeId
          AND b.bookingDate = :date
          AND b.status NOT IN (
              com.aiwa.enums.BookingStatus.CANCELLED,
              com.aiwa.enums.BookingStatus.REJECTED,
              com.aiwa.enums.BookingStatus.EXPIRED)
          AND b.startTime < :endTime
          AND b.endTime > :startTime
        """)
    boolean existsConflictExcluding(@Param("providerId") Long providerId,
                                    @Param("date") LocalDate date,
                                    @Param("startTime") LocalTime startTime,
                                    @Param("endTime") LocalTime endTime,
                                    @Param("excludeId") Long excludeId);

    @Query("""
        SELECT COUNT(b) > 0 FROM Booking b
        WHERE b.staffMember.id = :staffId
          AND b.id <> :excludeId
          AND b.bookingDate = :date
          AND b.status NOT IN (
              com.aiwa.enums.BookingStatus.CANCELLED,
              com.aiwa.enums.BookingStatus.REJECTED,
              com.aiwa.enums.BookingStatus.EXPIRED)
          AND b.startTime < :endTime
          AND b.endTime > :startTime
        """)
    boolean existsConflictForStaffExcluding(@Param("staffId") Long staffId,
                                            @Param("date") LocalDate date,
                                            @Param("startTime") LocalTime startTime,
                                            @Param("endTime") LocalTime endTime,
                                            @Param("excludeId") Long excludeId);

    /** Providers currently out on a visit — the "busy" flag on discovery rows. */
    @Query("""
        SELECT DISTINCT b.provider.id FROM Booking b
        WHERE b.provider.id IN :providerIds
          AND b.status IN (
              com.aiwa.enums.BookingStatus.ON_THE_WAY,
              com.aiwa.enums.BookingStatus.ARRIVED,
              com.aiwa.enums.BookingStatus.IN_PROGRESS)
        """)
    List<Long> findBusyProviderIds(@Param("providerIds") java.util.Collection<Long> providerIds);

    /** Accepted-or-later bookings created in a window — admin dashboard deltas. */
    long countByCreatedAtBetween(java.time.LocalDateTime from, java.time.LocalDateTime to);

    long countByStatusAndCreatedAtBetween(BookingStatus status, java.time.LocalDateTime from, java.time.LocalDateTime to);

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

    boolean existsBySavedAddressId(Long savedAddressId);

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

    /** GMV of bookings in a status created in [from, to) — dashboard 30-day tile. */
    @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.status = :status "
            + "AND b.createdAt >= :from AND b.createdAt < :to")
    java.math.BigDecimal sumRevenueByStatusBetween(@Param("status") BookingStatus status,
                                                   @Param("from") java.time.LocalDateTime from,
                                                   @Param("to") java.time.LocalDateTime to);

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

