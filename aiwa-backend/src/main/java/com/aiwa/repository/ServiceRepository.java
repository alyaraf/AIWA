package com.aiwa.repository;

import com.aiwa.entity.Service;
import com.aiwa.enums.ServiceCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ServiceRepository extends JpaRepository<Service, Long> {
    List<Service> findByProviderIdAndActiveTrue(Long providerId);
    List<Service> findByProviderIdAndCategory(Long providerId, ServiceCategory category);
    List<Service> findByProviderIdOrderByPriceAsc(Long providerId);
}
