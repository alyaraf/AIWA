package com.aiwa.controller;

import com.aiwa.dto.request.UpdatePushTokenRequest;
import com.aiwa.entity.PushDevice;
import com.aiwa.entity.User;
import com.aiwa.enums.DevicePlatform;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.PushDeviceRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.service.impl.AuthServiceImpl;
import com.aiwa.service.impl.FileStorageServiceImpl;
import com.aiwa.service.impl.OtpServiceImpl;
import com.aiwa.service.impl.PushDeviceService;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Push addresses per phone (R2-12): registering stores this phone for the
 * signed-in account (moving it away from any other account), and signing out
 * removes just that phone, or all of the user's phones when no token is given.
 */
class AuthControllerPushTokenTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final PushDeviceRepository deviceRepo = mock(PushDeviceRepository.class);
    private final PushDeviceService pushDevices = new PushDeviceService(deviceRepo);

    private final AuthController controller = new AuthController(mock(AuthServiceImpl.class), mock(OtpServiceImpl.class),
            userRepo, mock(com.aiwa.repository.ProviderProfileRepository.class), mock(FileStorageServiceImpl.class),
            mock(JwtUtils.class), mock(com.aiwa.repository.TermsPolicyRepository.class), pushDevices,
            mock(com.aiwa.service.impl.TermsAcceptanceService.class));

    private final User nour = User.builder().id(1L).email("nour@x.com").role(UserRole.CUSTOMER).build();

    private UserDetails principal() {
        when(userRepo.findByLogin("nour@x.com")).thenReturn(Optional.of(nour));
        return new org.springframework.security.core.userdetails.User(
                "nour@x.com", "pw", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    private static UpdatePushTokenRequest request(String token, DevicePlatform platform) {
        UpdatePushTokenRequest req = new UpdatePushTokenRequest();
        req.setToken(token);
        req.setPlatform(platform);
        return req;
    }

    @Test
    void registersTheDeviceForTheSignedInUser() {
        when(deviceRepo.findByToken("fcm-token-abc123")).thenReturn(Optional.empty());

        controller.updatePushToken(request("fcm-token-abc123", DevicePlatform.ANDROID), principal());

        verify(deviceRepo).save(argThat(d -> d.getUser() == nour && "fcm-token-abc123".equals(d.getToken())
                && d.getPlatform() == DevicePlatform.ANDROID));
    }

    @Test
    void aPhoneSharedByTwoAccountsMovesToTheOneSignedInNow() {
        User previous = User.builder().id(2L).email("old@x.com").role(UserRole.CUSTOMER).build();
        PushDevice shared = PushDevice.builder().id(5L).user(previous).token("shared").platform(DevicePlatform.IOS).build();
        when(deviceRepo.findByToken("shared")).thenReturn(Optional.of(shared));
        when(deviceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        controller.updatePushToken(request("shared", DevicePlatform.IOS), principal());

        assertThat(shared.getUser()).isSameAs(nour);
    }

    @Test
    void signingOutOnOnePhoneRemovesOnlyThatPhone() {
        controller.clearPushToken("phone-a", principal());

        verify(deviceRepo).deleteByUserIdAndToken(1L, "phone-a");
        verify(deviceRepo, never()).deleteByUserId(any());
    }

    @Test
    void withoutATokenEveryPhoneOfTheUserIsRemoved() {
        controller.clearPushToken(null, principal());

        verify(deviceRepo).deleteByUserId(1L);
    }
}
