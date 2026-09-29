package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

/** One portfolio photo. Hidden images stay on disk for audit but leave the public gallery. */
@Entity
@Table(name = "gallery_images")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class GalleryImage extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    /** Public URL path, e.g. "/files/public/gallery/&lt;uuid&gt;.jpg" (relative to the API base). */
    @Column(nullable = false, length = 512)
    private String url;

    @Builder.Default
    private boolean hidden = false;
}
