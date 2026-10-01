package com.aiwa.repository;

import com.aiwa.entity.SosDelivery;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface SosDeliveryRepository extends JpaRepository<SosDelivery, Long> {
    List<SosDelivery> findByEventIdOrderByIdAsc(Long eventId);

    List<SosDelivery> findByEventIdInOrderByIdAsc(Collection<Long> eventIds);
}
