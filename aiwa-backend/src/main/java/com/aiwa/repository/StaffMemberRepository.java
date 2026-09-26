package com.aiwa.repository;

import com.aiwa.entity.StaffMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface StaffMemberRepository extends JpaRepository<StaffMember, Long> {
    List<StaffMember> findByProviderIdAndActiveTrueOrderByFullNameAsc(Long providerId);
    List<StaffMember> findByProviderIdOrderByFullNameAsc(Long providerId);
    Optional<StaffMember> findByIdAndProviderId(Long id, Long providerId);
}
