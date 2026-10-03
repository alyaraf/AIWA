package com.aiwa.repository;

import com.aiwa.entity.SosDelivery;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

public interface SosDeliveryRepository extends JpaRepository<SosDelivery, Long> {
    List<SosDelivery> findByEventIdOrderByIdAsc(Long eventId);

    List<SosDelivery> findByEventIdInOrderByIdAsc(Collection<Long> eventIds);

    /**
     * CR-08: texts of OPEN SOS alerts that are not SENT and are due now, with
     * what the text is built from fetched (the sweep runs outside a transaction).
     */
    @Query("""
            select d from SosDelivery d
            join fetch d.event e join fetch e.actor join fetch e.booking b join fetch b.customer
            where e.resolved = false and d.status <> com.aiwa.enums.SosDeliveryStatus.SENT
              and (d.nextAttemptAt is null or d.nextAttemptAt <= :now)
            order by d.id""")
    List<SosDelivery> findDueForRetry(@Param("now") LocalDateTime now);
}
