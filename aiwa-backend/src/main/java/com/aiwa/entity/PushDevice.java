package com.aiwa.entity;

import com.aiwa.enums.DevicePlatform;
import jakarta.persistence.*;
import lombok.*;

/**
 * One phone's push address (R2-12). A user can be signed in on several phones,
 * and a token belongs to exactly one account: registering it moves it to the
 * account that is signed in now, so a shared phone stops getting the previous
 * account's notifications.
 */
@Entity
@Table(name = "push_devices")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PushDevice extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, unique = true, length = 512)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private DevicePlatform platform;
}
