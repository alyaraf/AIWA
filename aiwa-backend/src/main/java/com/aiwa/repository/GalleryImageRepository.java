package com.aiwa.repository;

import com.aiwa.entity.GalleryImage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface GalleryImageRepository extends JpaRepository<GalleryImage, Long> {
    List<GalleryImage> findByProviderIdOrderByIdAsc(Long providerId);
    Optional<GalleryImage> findByIdAndProviderId(Long id, Long providerId);
    long countByProviderId(Long providerId);
    /** A photo moderation hid; matched on the file name so rows that kept a pre-V13 disk path count too. */
    boolean existsByHiddenTrueAndUrlEndingWith(String suffix);
}
