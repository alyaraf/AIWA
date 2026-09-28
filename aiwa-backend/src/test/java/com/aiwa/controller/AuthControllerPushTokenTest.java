package com.aiwa.controller;

import com.aiwa.dto.request.UpdatePushTokenRequest;
import com.aiwa.entity.User;
import com.aiwa.enums.DevicePlatform;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.service.AuthService;
import com.aiwa.service.impl.FileStorageServiceImpl;
import com.aiwa.service.impl.OtpServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Fixes the actual missing piece for push delivery: somewhere to store a
 * device's registration id, and an endpoint the app calls to put one there.
 */
class AuthControllerPushTokenTest {

    private final AuthService authService = mock(AuthService.class);
    private final OtpServiceImpl otpService = mock(OtpServiceImpl.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final FileStorageServiceImpl fileStorageService = mock(FileStorageServiceImpl.class);

    private final AuthController controller = new AuthController(authService, otpService, userRepo, mock(com.aiwa.repository.ProviderProfileRepository.class), fileStorageService, mock(JwtUtils.class));

    private UserDetails principal(String email) {
        return new org.springframework.security.core.userdetails.User(
                email, "pw", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    @Test
    void registersTheDeviceTokenAndPlatform() {
        User user = User.builder().id(1L).email("nour@x.com").role(UserRole.CUSTOMER).build();
        when(userRepo.findByEmail("nour@x.com")).thenReturn(Optional.of(user));
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UpdatePushTokenRequest req = new UpdatePushTokenRequest();
        req.setToken("fcm-token-abc123");
        req.setPlatform(DevicePlatform.ANDROID);

        controller.updatePushToken(req, principal("nour@x.com"));

        assertThat(user.getPushToken()).isEqualTo("fcm-token-abc123");
        assertThat(user.getPushPlatform()).isEqualTo(DevicePlatform.ANDROID);
        verify(userRepo).save(user);
    }

    @Test
    void clearingRemovesTheStoredToken() {
        User user = User.builder().id(1L).email("nour@x.com").role(UserRole.CUSTOMER)
                .pushToken("old-token").pushPlatform(DevicePlatform.IOS).build();
        when(userRepo.findByEmail("nour@x.com")).thenReturn(Optional.of(user));
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        controller.clearPushToken(principal("nour@x.com"));

        assertThat(user.getPushToken()).isNull();
        assertThat(user.getPushPlatform()).isNull();
    }
}
