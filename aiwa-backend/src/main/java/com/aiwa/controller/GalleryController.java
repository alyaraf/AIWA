package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.FileStorageServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/provider/gallery")
@RequiredArgsConstructor
@Tag(name = "Gallery", description = "Provider portfolio image management")
public class GalleryController {

    private final ProviderProfileRepository providerRepo;
    private final FileStorageServiceImpl fileStorageService;
    private final UserRepository userRepo;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a gallery image (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<List<String>>> upload(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {

        ProviderProfile profile = getProfile(userDetails);

        if (profile.getGalleryImages().size() >= 20) {
            throw new BusinessException("gallery.error.max_images");
        }

        String path = fileStorageService.storePublic(image);
        profile.getGalleryImages().add(path);
        providerRepo.save(profile);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Image uploaded", profile.getGalleryImages()));
    }

    @DeleteMapping
    @Operation(summary = "Remove a gallery image by URL/path (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<List<String>>> remove(
            @RequestParam String imageUrl,
            @AuthenticationPrincipal UserDetails userDetails) {

        ProviderProfile profile = getProfile(userDetails);
        boolean removed = profile.getGalleryImages().remove(imageUrl);

        if (!removed) throw new BusinessException("gallery.error.not_found");

        fileStorageService.deletePublic(imageUrl);
        providerRepo.save(profile);

        return ResponseEntity.ok(ApiResponse.Success.of("Image removed", profile.getGalleryImages()));
    }

    @GetMapping("/{providerId}")
    @Operation(summary = "Get gallery images for a provider (public)")
    public ResponseEntity<ApiResponse.Success<List<String>>> getGallery(@PathVariable Long providerId) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        return ResponseEntity.ok(ApiResponse.Success.of(profile.getGalleryImages()));
    }

    private ProviderProfile getProfile(UserDetails ud) {
        Long userId = userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
        return providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
    }
}
