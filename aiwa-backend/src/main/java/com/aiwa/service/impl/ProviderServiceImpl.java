package com.aiwa.service.impl;

import com.aiwa.dto.request.ProviderProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.ProviderService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ProviderServiceImpl implements ProviderService {

    private final ProviderProfileRepository providerRepo;
    private final UserRepository userRepo;
    private final BookingRepository bookingRepo;
    private final RedisRuntimeService redis;

    private static final Duration PROVIDER_CACHE_TTL = Duration.ofMinutes(5);

    @Override
    @Transactional
    public ApiResponse.ProviderDetailDto createProfile(Long userId, ProviderProfileRequest req) {
        if (providerRepo.findByUserId(userId).isPresent()) {
            throw new BusinessException("provider.profile.already_exists");
        }
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));

        ProviderProfile profile = ProviderProfile.builder()
                .user(user)
                .businessName(req.getBusinessName())
                .bio(req.getBio())
                .address(req.getAddress())
                .latitude(req.getLatitude())
                .longitude(req.getLongitude())
                .providerType(req.getProviderType() != null ? req.getProviderType() : com.aiwa.enums.ProviderType.INDIVIDUAL)
                .primaryCategory(req.getPrimaryCategory())
                .travelBufferMinutes(req.getTravelBufferMinutes() != null ? req.getTravelBufferMinutes() : 0)
                .build();

        ProviderProfile saved = providerRepo.save(profile);
        clearProviderSearchCache();
        return toDetailDto(saved, null, null);
    }

    @Override
    @Transactional
    public ApiResponse.ProviderDetailDto updateProfile(Long userId, ProviderProfileRequest req) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        profile.setBusinessName(req.getBusinessName());
        profile.setBio(req.getBio());
        profile.setAddress(req.getAddress());
        profile.setLatitude(req.getLatitude());
        profile.setLongitude(req.getLongitude());
        if (req.getProviderType() != null) profile.setProviderType(req.getProviderType());
        profile.setPrimaryCategory(req.getPrimaryCategory());
        if (req.getTravelBufferMinutes() != null) profile.setTravelBufferMinutes(req.getTravelBufferMinutes());

        ProviderProfile saved = providerRepo.save(profile);
        clearProviderSearchCache();
        return toDetailDto(saved, null, null);
    }

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.ProviderDetailDto getById(Long providerId, Double userLat, Double userLng) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        return toDetailDto(profile, userLat, userLng);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderSummaryDto> getNearby(double lat, double lng, double radiusKm,
                                                           ServiceCategory category, String sort, Pageable pageable) {
        String cacheKey = nearbyCacheKey(lat, lng, radiusKm, category, sort, pageable);
        List<ProviderProfile> all = redis.getLongList(cacheKey)
                .map(this::findProvidersInOrder)
                .orElseGet(() -> {
                    List<ProviderProfile> fresh = (category != null)
                            ? providerRepo.findNearbyByCategory(lat, lng, radiusKm, category, pageable).getContent()
                            : providerRepo.findNearby(lat, lng, radiusKm);
                    redis.setLongList(cacheKey, fresh.stream().map(ProviderProfile::getId).toList(), PROVIDER_CACHE_TTL);
                    return fresh;
                });

        List<ApiResponse.ProviderSummaryDto> dtos = all.stream()
                .map(p -> toSummaryDto(p, lat, lng))
                .collect(Collectors.toList());

        // Apply sort
        java.util.Comparator<ApiResponse.ProviderSummaryDto> comparator = switch (sort != null ? sort : "distance") {
            case "rating"   -> java.util.Comparator.comparingDouble(
                                    d -> -(d.getAverageRating() != null ? d.getAverageRating() : 0.0));
            case "price"    -> java.util.Comparator.comparingDouble(
                                    d -> (d.getAverageRating() != null ? d.getAverageRating() : 0.0)); // placeholder — price sort added when min-price is on ProviderSummaryDto
            default         -> java.util.Comparator.comparingDouble(
                                    d -> (d.getDistanceKm() != null ? d.getDistanceKm() : 999.0));
        };
        dtos.sort(comparator);

        return new PageImpl<>(dtos, pageable, dtos.size());
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderSummaryDto> search(String query, Pageable pageable) {
        String cacheKey = searchCacheKey(query, pageable);
        List<ProviderProfile> profiles = redis.getLongList(cacheKey)
                .map(this::findProvidersInOrder)
                .orElseGet(() -> {
                    List<ProviderProfile> fresh = providerRepo.searchByName(query, pageable).getContent();
                    redis.setLongList(cacheKey, fresh.stream().map(ProviderProfile::getId).toList(), PROVIDER_CACHE_TTL);
                    return fresh;
                });
        List<ApiResponse.ProviderSummaryDto> dtos = profiles.stream()
                .map(p -> toSummaryDto(p, null, null))
                .toList();
        return new PageImpl<>(dtos, pageable, dtos.size());
    }

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.DashboardDto getDashboard(Long userId) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        long total     = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.ACCEPTED)
                       + bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.PENDING)
                       + bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.COMPLETED);
        long pending   = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.PENDING);
        long confirmed = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.ACCEPTED);
        long completed = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.COMPLETED);

        List<Booking> todayBookings = bookingRepo.findByProviderIdAndBookingDate(profile.getId(), LocalDate.now());

        BigDecimal revenue = todayBookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.COMPLETED)
                .map(Booking::getTotalPrice)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<ApiResponse.BookingDto> todayDtos = todayBookings.stream()
                .map(this::toBookingDto)
                .collect(Collectors.toList());

        return ApiResponse.DashboardDto.builder()
                .totalBookings(total)
                .pendingBookings(pending)
                .confirmedBookings(confirmed)
                .completedBookings(completed)
                .totalRevenue(revenue)
                .averageRating(profile.getAverageRating())
                .totalClients((long) todayBookings.stream()
                        .map(b -> b.getCustomer().getId()).distinct().count())
                .todayBookings(todayDtos)
                .build();
    }

    // ── mappers ───────────────────────────────────────────────────────────────

    private ApiResponse.ProviderDetailDto toDetailDto(ProviderProfile p, Double lat, Double lng) {
        List<ApiResponse.ServiceDto> services = p.getServices().stream()
                .filter(s -> s.isActive())
                .map(this::toServiceDto)
                .collect(Collectors.toList());

        List<ApiResponse.AvailabilityDto> availabilities = p.getAvailabilities().stream()
                .map(this::toAvailabilityDto)
                .collect(Collectors.toList());

        List<ApiResponse.StaffMemberDto> staff = p.getStaffMembers().stream()
                .filter(StaffMember::isActive)
                .map(this::toStaffDto)
                .collect(Collectors.toList());

        return ApiResponse.ProviderDetailDto.builder()
                .id(p.getId())
                .businessName(p.getBusinessName())
                .bio(p.getBio())
                .address(p.getAddress())
                .latitude(p.getLatitude())
                .longitude(p.getLongitude())
                .primaryCategory(p.getPrimaryCategory())
                .averageRating(p.getAverageRating())
                .totalReviews(p.getTotalReviews())
                .verificationStatus(p.getVerificationStatus())
                .providerType(p.getProviderType())
                .vacationMode(p.isVacationMode())
                .offlineMode(p.isOfflineMode())
                .travelBufferMinutes(p.getTravelBufferMinutes())
                .settlementPaused(p.isSettlementPaused())
                .homeServiceTravelFee(p.getHomeServiceTravelFee())
                .owner(toUserDto(p.getUser()))
                .services(services)
                .availabilities(availabilities)
                .staffMembers(staff)
                .galleryImages(p.getGalleryImages())
                .distanceKm(lat != null ? haversine(lat, lng, p.getLatitude(), p.getLongitude()) : null)
                .build();
    }

    public ApiResponse.ProviderSummaryDto toSummaryDto(ProviderProfile p, Double lat, Double lng) {
        return ApiResponse.ProviderSummaryDto.builder()
                .id(p.getId())
                .businessName(p.getBusinessName())
                .address(p.getAddress())
                .latitude(p.getLatitude())
                .longitude(p.getLongitude())
                .primaryCategory(p.getPrimaryCategory())
                .averageRating(p.getAverageRating())
                .totalReviews(p.getTotalReviews())
                .verificationStatus(p.getVerificationStatus())
                .ownerName(p.getUser().getFullName())
                .providerType(p.getProviderType())
                .vacationMode(p.isVacationMode())
                .offlineMode(p.isOfflineMode())
                .settlementPaused(p.isSettlementPaused())
                .distanceKm(lat != null ? haversine(lat, lng, p.getLatitude(), p.getLongitude()) : null)
                .build();
    }

    private ApiResponse.ServiceDto toServiceDto(com.aiwa.entity.Service s) {
        return ApiResponse.ServiceDto.builder()
                .id(s.getId())
                .name(s.getName())
                .description(s.getDescription())
                .price(s.getPrice())
                .durationMinutes(s.getDurationMinutes())
                .category(s.getCategory())
                .pricingType(s.getPricingType())
                .transportIncluded(s.isTransportIncluded())
                .active(s.isActive())
                .build();
    }

    private ApiResponse.AvailabilityDto toAvailabilityDto(Availability a) {
        return ApiResponse.AvailabilityDto.builder()
                .id(a.getId())
                .dayOfWeek(a.getDayOfWeek())
                .startTime(a.getStartTime())
                .endTime(a.getEndTime())
                .slotDurationMinutes(a.getSlotDurationMinutes())
                .available(a.isAvailable())
                .build();
    }

    private ApiResponse.UserDto toUserDto(User u) {
        return ApiResponse.UserDto.builder()
                .id(u.getId())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .preferredLanguage(u.getPreferredLanguage())
                .termsAccepted(u.isTermsAccepted())
                .active(u.isActive())
                .build();
    }

    private ApiResponse.StaffMemberDto toStaffDto(StaffMember s) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
                .phone(s.getPhone())
                .active(s.isActive())
                .build();
    }

    private ApiResponse.BookingDto toBookingDto(Booking b) {
        return ApiResponse.BookingDto.builder()
                .id(b.getId())
                .customer(toUserDto(b.getCustomer()))
                .provider(ApiResponse.ProviderSummaryDto.builder()
                        .id(b.getProvider().getId())
                        .businessName(b.getProvider().getBusinessName())
                        .build())
                .service(toServiceDto(b.getService()))
                .bookingDate(b.getBookingDate())
                .startTime(b.getStartTime())
                .endTime(b.getEndTime())
                .bookingType(b.getBookingType())
                .estimatedArrivalMinutes(b.getEstimatedArrivalMinutes())
                .staffMember(b.getStaffMember() != null ? toStaffDto(b.getStaffMember()) : null)
                .homeService(b.isHomeService())
                .status(b.getStatus())
                .paymentStatus(b.getPaymentStatus())
                .paymentMethod(b.getPaymentMethod())
                .totalPrice(b.getTotalPrice())
                .notes(b.getNotes())
                .cancellationReason(b.getCancellationReason())
                .cancelledBy(b.getCancelledBy())
                .cancelledAt(b.getCancelledAt())
                .rejectionReason(b.getRejectionReason())
                .createdAt(b.getCreatedAt())
                .reviewed(b.getReviews() != null && !b.getReviews().isEmpty())
                .build();
    }

    private static double haversine(double lat1, double lon1, Double lat2, Double lon2) {
        if (lat2 == null || lon2 == null) return -1;
        final int R = 6371;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private List<ProviderProfile> findProvidersInOrder(List<Long> ids) {
        Map<Long, ProviderProfile> byId = providerRepo.findAllById(ids).stream()
                .collect(Collectors.toMap(ProviderProfile::getId, p -> p, (a, b) -> a, LinkedHashMap::new));
        return ids.stream()
                .map(byId::get)
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    private String nearbyCacheKey(double lat, double lng, double radiusKm, ServiceCategory category, String sort, Pageable pageable) {
        return "cache:providers:nearby:"
                + Math.round(lat * 1000) + ":"
                + Math.round(lng * 1000) + ":"
                + Math.round(radiusKm * 10) + ":"
                + (category != null ? category.name() : "all") + ":"
                + (sort != null ? sort : "distance") + ":"
                + pageable.getPageNumber() + ":"
                + pageable.getPageSize();
    }

    private String searchCacheKey(String query, Pageable pageable) {
        return "cache:providers:search:"
                + (query != null ? query.trim().toLowerCase() : "") + ":"
                + pageable.getPageNumber() + ":"
                + pageable.getPageSize();
    }

    private void clearProviderSearchCache() {
        // Search keys are short-lived; TTL keeps invalidation cheap and avoids scan in request paths.
    }
}
