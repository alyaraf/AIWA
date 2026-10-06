package com.aiwa.repository;

import com.aiwa.entity.SafetyEvent;
import com.aiwa.enums.SafetyEventType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SafetyEventRepository extends JpaRepository<SafetyEvent, Long> {
    List<SafetyEvent> findByBookingIdOrderByCreatedAtAsc(Long bookingId);

    Optional<SafetyEvent> findByIdAndBookingId(Long id, Long bookingId);

    /** Admin SOS queue. */
    Page<SafetyEvent> findByTypeAndResolvedOrderByCreatedAtDesc(SafetyEventType type, boolean resolved, Pageable pageable);

    Page<SafetyEvent> findByTypeOrderByCreatedAtDesc(SafetyEventType type, Pageable pageable);

    /**
     * R5 follow-up: the admin SOS queue searched and paged on the server. {@code flags} is the set of "resolved" values to
     * show ([false] open, [true] closed, both for ALL). {@code q} is a lower-case LIKE pattern (com.aiwa.util.Searches,
     * "%" = no search) matched against the person who raised it, the customer, the provider, the booking number, the note
     * and the resolution note. The order comes from the Pageable's Sort (the service sets createdAt, then id).
     */
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"actor", "booking", "booking.customer",
            "booking.provider", "booking.provider.user", "resolvedBy"})
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT e FROM SafetyEvent e JOIN e.actor a JOIN e.booking b JOIN b.customer cu JOIN b.provider pr "
                    + "WHERE e.type = :type AND e.resolved IN :flags AND (LOWER(a.fullName) LIKE :q OR LOWER(cu.fullName) LIKE :q "
                    + "OR LOWER(pr.businessName) LIKE :q OR CAST(b.id AS string) LIKE :q OR LOWER(COALESCE(a.phone, '')) LIKE :q "
                    + "OR LOWER(COALESCE(e.notes, '')) LIKE :q OR LOWER(COALESCE(e.resolutionNotes, '')) LIKE :q)",
            countQuery = "SELECT COUNT(e) FROM SafetyEvent e JOIN e.actor a JOIN e.booking b JOIN b.customer cu JOIN b.provider pr "
                    + "WHERE e.type = :type AND e.resolved IN :flags AND (LOWER(a.fullName) LIKE :q OR LOWER(cu.fullName) LIKE :q "
                    + "OR LOWER(pr.businessName) LIKE :q OR CAST(b.id AS string) LIKE :q OR LOWER(COALESCE(a.phone, '')) LIKE :q "
                    + "OR LOWER(COALESCE(e.notes, '')) LIKE :q OR LOWER(COALESCE(e.resolutionNotes, '')) LIKE :q)")
    Page<SafetyEvent> search(@org.springframework.data.repository.query.Param("type") SafetyEventType type,
                             @org.springframework.data.repository.query.Param("flags") java.util.Collection<Boolean> flags,
                             @org.springframework.data.repository.query.Param("q") String q, Pageable pageable);

    long countByTypeAndResolvedFalse(SafetyEventType type);

    Optional<SafetyEvent> findFirstByTypeAndResolvedFalseOrderByCreatedAtAsc(SafetyEventType type);

    Optional<SafetyEvent> findFirstByBookingIdAndActorIdAndTypeAndResolvedFalseOrderByCreatedAtDesc(
            Long bookingId, Long actorId, SafetyEventType type);

    long countByActorIdAndTypeAndCreatedAtAfter(Long actorId, SafetyEventType type, java.time.LocalDateTime after);
}
