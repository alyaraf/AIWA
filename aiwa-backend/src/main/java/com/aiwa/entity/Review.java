package com.aiwa.entity;

import com.aiwa.enums.ReviewDirection;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "reviews")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Review extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ReviewDirection direction = ReviewDirection.CUSTOMER_TO_PROVIDER;

    @Column(nullable = false)
    private Integer rating;   // 1 – 5

    @Column(length = 1000)
    private String comment;

    /** Hidden by admin moderation — excluded from public listings and rating. */
    @Builder.Default
    private boolean hidden = false;

    /** The provider's public reply to a customer review (one reply, editable). */
    @Column(length = 1000)
    private String reply;

    private java.time.LocalDateTime repliedAt;

    /** Quick-tags selected by the customer (e.g. "Punctual", "Skilled") */
    @ElementCollection
    @CollectionTable(name = "review_tags", joinColumns = @JoinColumn(name = "review_id"))
    @Column(name = "tag")
    private java.util.List<String> quickTags = new java.util.ArrayList<>();
}
