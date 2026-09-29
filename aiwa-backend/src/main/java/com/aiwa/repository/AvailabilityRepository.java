package com.aiwa.repository;

import com.aiwa.entity.Availability;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.DayOfWeek;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface AvailabilityRepository extends JpaRepository<Availability, Long> {
    List<Availability> findByProviderIdAndAvailableTrue(Long providerId);
    /** Any row for the day (a shop may only have per-staff rows) — "first", never a multi-row error. */
    Optional<Availability> findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc(Long providerId, DayOfWeek dayOfWeek);

    // Provider-level (individual) rows have a null staff member.
    Optional<Availability> findByProviderIdAndStaffMemberIsNullAndDayOfWeek(Long providerId, DayOfWeek dayOfWeek);
    Optional<Availability> findByProviderIdAndStaffMemberIdAndDayOfWeek(Long providerId, Long staffMemberId, DayOfWeek dayOfWeek);
    List<Availability> findByProviderIdAndStaffMemberId(Long providerId, Long staffMemberId);

    /** Today's open rows for a batch of providers (provider-level and per-staff). */
    List<Availability> findByProviderIdInAndDayOfWeekAndAvailableTrue(Collection<Long> providerIds, DayOfWeek dayOfWeek);
}
