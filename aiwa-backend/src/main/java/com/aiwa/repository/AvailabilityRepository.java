package com.aiwa.repository;

import com.aiwa.entity.Availability;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Optional;

@Repository
public interface AvailabilityRepository extends JpaRepository<Availability, Long> {
    List<Availability> findByProviderIdAndAvailableTrue(Long providerId);
    Optional<Availability> findByProviderIdAndDayOfWeek(Long providerId, DayOfWeek dayOfWeek);

    // Provider-level (individual) rows have a null staff member.
    Optional<Availability> findByProviderIdAndStaffMemberIsNullAndDayOfWeek(Long providerId, DayOfWeek dayOfWeek);
    Optional<Availability> findByProviderIdAndStaffMemberIdAndDayOfWeek(Long providerId, Long staffMemberId, DayOfWeek dayOfWeek);
    List<Availability> findByProviderIdAndStaffMemberId(Long providerId, Long staffMemberId);
}
