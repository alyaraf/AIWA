package com.aiwa.controller;

import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.GalleryImage;
import com.aiwa.entity.ModerationCase;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.GalleryImageRepository;
import com.aiwa.repository.ModerationCaseRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.FileStorageServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequiredArgsConstructor
@Tag(name = "Gallery", description = "Provider portfolio image management")
public class GalleryController {

    static final int MAX_IMAGES = 20;

    private final ProviderProfileRepository providerRepo;
    private final GalleryImageRepository galleryRepo;
    private final ModerationCaseRepository moderationRepo;
    private final FileStorageServiceImpl fileStorageService;
    private final UserRepository userRepo;

    /** DR-028: per-account budget (absent in plain unit tests). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.aiwa.service.impl.AccountRateLimiter limiter;

    @PostMapping(value = "/provider/gallery", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional
    @Operation(summary = "Upload a gallery image (PROVIDER role) — returns the provider's image URLs")
    public ResponseEntity<ApiResponse.Success<List<String>>> upload(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {

        ProviderProfile profile = getProfile(userDetails);
        if (limiter != null) limiter.check(profile.getUser().getId(), "upload", 30, java.time.Duration.ofHours(1));
        if (galleryRepo.countByProviderId(profile.getId()) >= MAX_IMAGES) {
            throw new BusinessException("gallery.error.max_images");
        }

        String url = fileStorageService.storePublic(image);
        galleryRepo.save(GalleryImage.builder().provider(profile).url(url).build());

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Image uploaded", ownUrls(profile.getId())));
    }

    @DeleteMapping("/provider/gallery")
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional
    @Operation(summary = "Remove one of your gallery images by URL (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<List<String>>> remove(
            @RequestParam String imageUrl,
            @AuthenticationPrincipal UserDetails userDetails) {

        ProviderProfile profile = getProfile(userDetails);
        GalleryImage image = galleryRepo.findByProviderIdOrderByIdAsc(profile.getId()).stream()
                .filter(g -> g.getUrl().equals(imageUrl))
                .findFirst()
                .orElseThrow(() -> new BusinessException("gallery.error.not_found"));
        deleteImage(image);
        return ResponseEntity.ok(ApiResponse.Success.of("Image removed", ownUrls(profile.getId())));
    }

    @GetMapping("/provider/gallery/{providerId}")
    @Transactional(readOnly = true)
    @Operation(summary = "Get the public gallery of a provider (hidden images excluded)")
    public ResponseEntity<ApiResponse.Success<List<String>>> getGallery(@PathVariable Long providerId) {
        if (!providerRepo.existsById(providerId)) throw new ResourceNotFoundException("Provider", providerId);
        return ResponseEntity.ok(ApiResponse.Success.of(galleryRepo.findByProviderIdOrderByIdAsc(providerId).stream()
                .filter(g -> !g.isHidden()).map(GalleryImage::getUrl).toList()));
    }

    @GetMapping("/provider/gallery-images")
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional(readOnly = true)
    @Operation(summary = "Your gallery with image ids and moderation state (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.GalleryImageDto>>> mine(
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile profile = getProfile(userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of(galleryRepo.findByProviderIdOrderByIdAsc(profile.getId())
                .stream().map(GalleryController::toDto).toList()));
    }

    @DeleteMapping("/provider/gallery-images/{imageId}")
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional
    @Operation(summary = "Remove one of your gallery images by id (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<Void>> removeById(
            @PathVariable Long imageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile profile = getProfile(userDetails);
        GalleryImage image = galleryRepo.findByIdAndProviderId(imageId, profile.getId())
                .orElseThrow(() -> new BusinessException("gallery.error.not_found"));
        deleteImage(image);
        return ResponseEntity.ok(ApiResponse.Success.of("Image removed", null));
    }

    @PostMapping("/providers/{providerId}/gallery/{imageId}/report")
    @Transactional
    @Operation(summary = "Report a gallery photo for moderation (any signed-in user)")
    public ResponseEntity<ApiResponse.Success<Void>> report(
            @PathVariable Long providerId,
            @PathVariable Long imageId,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body) {
        reason = FreeTextBody.pick(body, "reason", reason);
        galleryRepo.findByIdAndProviderId(imageId, providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Gallery image", imageId));
        // One open case per photo is enough for the queue.
        boolean open = moderationRepo.existsByStatusAndTargetTypeAndTargetId(
                ModerationStatus.OPEN, ModerationTargetType.GALLERY_IMAGE, imageId);
        if (!open) {
            moderationRepo.save(ModerationCase.builder()
                    .targetType(ModerationTargetType.GALLERY_IMAGE)
                    .targetId(imageId)
                    .reason(reason == null || reason.isBlank() ? "Reported by a user"
                            : reason.substring(0, Math.min(reason.length(), 1000)))
                    .build());
        }
        return ResponseEntity.ok(ApiResponse.Success.of("Photo reported", null));
    }

    private void deleteImage(GalleryImage image) {
        galleryRepo.delete(image);
        fileStorageService.deletePublic(image.getUrl());
    }

    private List<String> ownUrls(Long providerId) {
        return galleryRepo.findByProviderIdOrderByIdAsc(providerId).stream().map(GalleryImage::getUrl).toList();
    }

    static ApiResponse.GalleryImageDto toDto(GalleryImage g) {
        return ApiResponse.GalleryImageDto.builder()
                .id(g.getId()).url(g.getUrl()).hidden(g.isHidden()).createdAt(g.getCreatedAt()).build();
    }

    private ProviderProfile getProfile(UserDetails ud) {
        Long userId = userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
        return providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
    }
}
