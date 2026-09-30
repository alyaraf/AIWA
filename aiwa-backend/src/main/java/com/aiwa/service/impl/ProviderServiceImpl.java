package com.aiwa.service.impl;

import com.aiwa.dto.request.ProviderProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ProviderType;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.ProviderService;
import com.aiwa.util.AiwaTime;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ProviderServiceImpl implements ProviderService {

    private final ProviderProfileRepository providerRepo;
    private final UserRepository userRepo;
    private final BookingRepository bookingRepo;
    private final ServiceRepository serviceRepo;
    private final AvailabilityRepository availabilityRepo;
    private final RedisRuntimeService redis;

    private static final Duration PROVIDER_CACHE_TTL = Duration.ofMinutes(5);
    private static final int MAX_PAGE_SIZE = 50;

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
                .providerType(req.getProviderType() != null ? req.getProviderType() : ProviderType.INDIVIDUAL)
                .primaryCategory(req.getPrimaryCategory())
                .travelBufferMinutes(req.getTravelBufferMinutes() != null ? req.getTravelBufferMinutes() : 0)
                .serviceRadiusKm(req.getServiceRadiusKm())
                .build();

        ProviderProfile saved = providerRepo.save(profile);
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
        if (req.getServiceRadiusKm() != null) profile.setServiceRadiusKm(req.getServiceRadiusKm());

        ProviderProfile saved = providerRepo.save(profile);
        return toDetailDto(saved, null, null);
    }

    /** PATCH /provider/mode/service-radius — how far the provider travels for home service. */
    @Transactional
    public ApiResponse.ProviderDetailDto updateServiceRadius(Long userId, Double radiusKm) {
        if (radiusKm != null && (radiusKm <= 0 || radiusKm > 200)) {
            throw new BusinessException("provider.service_radius.invalid");
        }
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        profile.setServiceRadiusKm(radiusKm);
        return toDetailDto(providerRepo.save(profile), null, null);
    }

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.ProviderDetailDto getById(Long providerId, Double userLat, Double userLng) {
        return getById(providerId, userLat, userLng, false);
    }

    /**
     * @param signedIn whether the caller is authenticated — only then does the
     *                 owner block carry the business phone (Call / WhatsApp buttons).
     */
    @Transactional(readOnly = true)
    public ApiResponse.ProviderDetailDto getById(Long providerId, Double userLat, Double userLng, boolean signedIn) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        ApiResponse.ProviderDetailDto dto = toDetailDto(profile, userLat, userLng);
        if (signedIn && dto.getOwner() != null) {
            dto.getOwner().setPhone(profile.getUser().getPhone());
        }
        return dto;
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderSummaryDto> getNearby(double lat, double lng, double radiusKm,
                                                           ServiceCategory category, String sort, Pageable pageable) {
        return getNearby(lat, lng, radiusKm, category, sort, null, pageable);
    }

    /**
     * Everything within the radius is sorted first and only then paged, so page 2
     * continues page 1. (Before, the unfiltered query returned every provider on
     * every page, the category query paged by rating before the distance sort, and
     * "price" sorted by rating.)
     */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderSummaryDto> getNearby(double lat, double lng, double radiusKm,
                                                           ServiceCategory category, String sort,
                                                           BigDecimal maxPrice, Pageable pageable) {
        double radius = Math.max(0.1, Math.min(radiusKm, 100));
        String cacheKey = nearbyCacheKey(lat, lng, radius, category);
        List<ProviderProfile> all = redis.getLongList(cacheKey)
                .map(this::findProvidersInOrder)
                .orElseGet(() -> {
                    List<ProviderProfile> fresh = (category != null)
                            ? providerRepo.findNearbyByCategory(lat, lng, radius, category)
                            : providerRepo.findNearby(lat, lng, radius);
                    redis.setLongList(cacheKey, fresh.stream().map(ProviderProfile::getId).toList(), PROVIDER_CACHE_TTL);
                    return fresh;
                });

        List<ApiResponse.ProviderSummaryDto> dtos = new ArrayList<>(toSummaryDtos(all, lat, lng));
        if (maxPrice != null) {
            dtos.removeIf(d -> d.getStartingPrice() == null || d.getStartingPrice().compareTo(maxPrice) > 0);
        }

        Comparator<ApiResponse.ProviderSummaryDto> byDistance = Comparator.comparingDouble(
                d -> d.getDistanceKm() != null && d.getDistanceKm() >= 0 ? d.getDistanceKm() : Double.MAX_VALUE);
        Comparator<ApiResponse.ProviderSummaryDto> comparator = switch (sort != null ? sort : "distance") {
            case "rating" -> Comparator.<ApiResponse.ProviderSummaryDto>comparingDouble(
                    d -> -(d.getAverageRating() != null ? d.getAverageRating() : 0.0)).thenComparing(byDistance);
            case "price" -> Comparator.comparing(ApiResponse.ProviderSummaryDto::getStartingPrice,
                    Comparator.nullsLast(Comparator.naturalOrder())).thenComparing(byDistance);
            default -> byDistance;
        };
        dtos.sort(comparator);
        return slice(dtos, pageable);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderSummaryDto> search(String query, Pageable pageable) {
        String q = query == null ? "" : query.trim();
        if (q.length() > 100) q = q.substring(0, 100);
        // Escape LIKE wildcards so "%" or "_" in the box match literally.
        String escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        Page<ProviderProfile> page = providerRepo.searchByName(escaped, clamp(pageable));
        List<ApiResponse.ProviderSummaryDto> dtos = toSummaryDtos(page.getContent(), null, null);
        return new PageImpl<>(dtos, page.getPageable(), page.getTotalElements());
    }

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.DashboardDto getDashboard(Long userId) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        long pending   = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.PENDING);
        long confirmed = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.ACCEPTED);
        long completed = bookingRepo.countByProviderAndStatus(profile.getId(), BookingStatus.COMPLETED);
        long total     = pending + confirmed + completed;

        List<Booking> todayBookings = bookingRepo.findByProviderIdAndBookingDate(profile.getId(), AiwaTime.today());

        BigDecimal revenue = todayBookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.COMPLETED)
                .map(Booking::getTotalPrice)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<ApiResponse.BookingDto> todayDtos = todayBookings.stream()
                .sorted(Comparator.comparing(Booking::getStartTime))
                .map(this::toBookingDto)
                .collect(Collectors.toList());

        return ApiResponse.DashboardDto.builder()
                .totalBookings(total)
                .pendingBookings(pending)
                .confirmedBookings(confirmed)
                .completedBookings(completed)
                .totalRevenue(revenue)
                .averageRating(profile.getAverageRating())
                .totalReviews(profile.getTotalReviews() == null ? 0 : profile.getTotalReviews())
                .totalClients((long) todayBookings.stream()
                        .map(b -> b.getCustomer().getId()).distinct().count())
                .todayBookings(todayDtos)
                .build();
    }

    // ── summary enrichment (one query per field for the whole list) ──────────

    /** Single provider — used where only one row is shown. */
    public ApiResponse.ProviderSummaryDto toSummaryDto(ProviderProfile p, Double lat, Double lng) {
        return toSummaryDtos(List.of(p), lat, lng).get(0);
    }

    public List<ApiResponse.ProviderSummaryDto> toSummaryDtos(List<ProviderProfile> providers, Double lat, Double lng) {
        if (providers.isEmpty()) return List.of();
        List<Long> ids = providers.stream().map(ProviderProfile::getId).toList();

        Map<Long, BigDecimal> minPrice = new HashMap<>();
        for (Object[] row : serviceRepo.minActivePriceByProvider(ids)) {
            minPrice.put((Long) row[0], (BigDecimal) row[1]);
        }
        LocalTime now = AiwaTime.timeNow();
        Map<Long, List<Availability>> today = availabilityRepo
                .findByProviderIdInAndDayOfWeekAndAvailableTrue(ids, AiwaTime.today().getDayOfWeek())
                .stream().collect(Collectors.groupingBy(a -> a.getProvider().getId()));
        Set<Long> busy = new HashSet<>(bookingRepo.findBusyProviderIds(ids));

        return providers.stream().map(p -> {
            boolean accepting = p.getVerificationStatus() == VerificationStatus.APPROVED
                    && !p.isVacationMode() && !p.isOfflineMode() && !p.isSettlementPaused();
            boolean withinHours = today.getOrDefault(p.getId(), List.of()).stream()
                    .anyMatch(a -> !now.isBefore(a.getStartTime()) && now.isBefore(a.getEndTime()));
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
                    .verifiedAt(p.getVerifiedAt())
                    .ownerName(p.getUser().getFullName())
                    .profileImageUrl(p.getUser().getProfileImageUrl())
                    .providerType(p.getProviderType())
                    .vacationMode(p.isVacationMode())
                    .offlineMode(p.isOfflineMode())
                    .settlementPaused(p.isSettlementPaused())
                    .startingPrice(minPrice.get(p.getId()))
                    .openNow(accepting && withinHours)
                    // A shop has several people; only an individual is "busy" as a whole.
                    .busyNow(p.getProviderType() == ProviderType.INDIVIDUAL && busy.contains(p.getId()))
                    .distanceKm(lat != null && lng != null ? haversine(lat, lng, p.getLatitude(), p.getLongitude()) : null)
                    .build();
        }).toList();
    }

    // ── mappers ───────────────────────────────────────────────────────────────

    private ApiResponse.ProviderDetailDto toDetailDto(ProviderProfile p, Double lat, Double lng) {
        List<ApiResponse.ServiceDto> services = p.getServices().stream()
                .filter(com.aiwa.entity.Service::isActive)
                .map(this::toServiceDto)
                .collect(Collectors.toList());

        List<ApiResponse.AvailabilityDto> availabilities = p.getAvailabilities().stream()
                .map(this::toAvailabilityDto)
                .collect(Collectors.toList());

        List<ApiResponse.StaffMemberDto> staff = p.getStaffMembers().stream()
                .filter(StaffMember::isActive)
                .map(this::toStaffDto)
                .collect(Collectors.toList());

        ApiResponse.ProviderSummaryDto summary = toSummaryDto(p, lat, lng);

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
                .verifiedAt(p.getVerifiedAt())
                .providerType(p.getProviderType())
                .vacationMode(p.isVacationMode())
                .offlineMode(p.isOfflineMode())
                .travelBufferMinutes(p.getTravelBufferMinutes())
                .settlementPaused(p.isSettlementPaused())
                .homeServiceTravelFee(p.getHomeServiceTravelFee())
                .serviceRadiusKm(p.getServiceRadiusKm())
                .owner(toPublicOwnerDto(p.getUser()))
                .services(services)
                .availabilities(availabilities)
                .staffMembers(staff)
                .galleryImages(p.getVisibleGalleryUrls())
                .gallery(p.getGallery().stream().filter(g -> !g.isHidden())
                        .map(g -> ApiResponse.GalleryImageDto.builder().id(g.getId()).url(g.getUrl()).build())
                        .toList())
                .startingPrice(summary.getStartingPrice())
                .openNow(summary.getOpenNow())
                .busyNow(summary.getBusyNow())
                .distanceKm(summary.getDistanceKm())
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
                .staffMemberId(a.getStaffMember() != null ? a.getStaffMember().getId() : null)
                .dayOfWeek(a.getDayOfWeek())
                .startTime(a.getStartTime())
                .endTime(a.getEndTime())
                .slotDurationMinutes(a.getSlotDurationMinutes())
                .available(a.isAvailable())
                .build();
    }

    /**
     * The owner block on a PUBLIC provider page. Contact details are left out —
     * GET /providers/{id} needs no authentication, so including them handed every
     * provider's personal phone and email to anyone scraping the API. Signed-in
     * callers get the phone added back in {@link #getById(Long, Double, Double, boolean)};
     * the email is never public.
     */
    private ApiResponse.UserDto toPublicOwnerDto(User u) {
        return ApiResponse.UserDto.builder()
                .id(u.getId())
                .fullName(u.getFullName())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .active(u.isActive())
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
                .skills(s.getSkills())
                .active(s.isActive())
                .serviceIds(s.getServices().stream().map(com.aiwa.entity.Service::getId).sorted().toList())
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
                .travelFee(b.getTravelFee())
                .notes(b.getNotes())
                .cancellationReason(b.getCancellationReason())
                .cancelledBy(b.getCancelledBy())
                .cancelledAt(b.getCancelledAt())
                .rejectionReason(b.getRejectionReason())
                .createdAt(b.getCreatedAt())
                .reviewed(b.getReviews() != null && !b.getReviews().isEmpty())
                .build();
    }

    private static Double haversine(double lat1, double lon1, Double lat2, Double lon2) {
        if (lat2 == null || lon2 == null) return null;
        return GeoUtils.distanceKm(lat1, lon1, lat2, lon2);
    }

    private static <T> Page<T> slice(List<T> all, Pageable pageable) {
        Pageable p = clamp(pageable);
        int from = (int) Math.min(p.getOffset(), all.size());
        int to = Math.min(from + p.getPageSize(), all.size());
        return new PageImpl<>(all.subList(from, to), p, all.size());
    }

    private static Pageable clamp(Pageable pageable) {
        int size = Math.max(1, Math.min(pageable.getPageSize(), MAX_PAGE_SIZE));
        return PageRequest.of(Math.max(0, pageable.getPageNumber()), size);
    }

    private List<ProviderProfile> findProvidersInOrder(List<Long> ids) {
        Map<Long, ProviderProfile> byId = providerRepo.findAllById(ids).stream()
                .collect(Collectors.toMap(ProviderProfile::getId, p -> p, (a, b) -> a, LinkedHashMap::new));
        // Cached ids can be up to 5 minutes old: a provider suspended by an admin
        // since then must not keep showing up in search (BE-41).
        return ids.stream()
                .map(byId::get)
                .filter(Objects::nonNull)
                .filter(p -> p.getVerificationStatus() == com.aiwa.enums.VerificationStatus.APPROVED)
                .toList();
    }

    private String nearbyCacheKey(double lat, double lng, double radiusKm, ServiceCategory category) {
        return "cache:providers:nearby:v2:"
                + Math.round(lat * 1000) + ":"
                + Math.round(lng * 1000) + ":"
                + Math.round(radiusKm * 10) + ":"
                + (category != null ? category.name() : "all");
    }
}
