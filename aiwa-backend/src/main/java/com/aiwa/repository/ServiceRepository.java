package com.aiwa.repository;

import com.aiwa.entity.Service;
import com.aiwa.enums.ServiceCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface ServiceRepository extends JpaRepository<Service, Long> {
    List<Service> findByProviderIdAndActiveTrue(Long providerId);
    List<Service> findByProviderIdAndCategory(Long providerId, ServiceCategory category);
    List<Service> findByProviderIdOrderByPriceAsc(Long providerId);
    List<Service> findByIdInAndProviderId(Collection<Long> ids, Long providerId);

    /** [providerId, min(price)] over active services — one query for a whole result list. */
    @Query("""
        SELECT s.provider.id, MIN(s.price) FROM Service s
        WHERE s.active = true AND s.provider.id IN :providerIds
        GROUP BY s.provider.id
        """)
    List<Object[]> minActivePriceByProvider(@Param("providerIds") Collection<Long> providerIds);
}
