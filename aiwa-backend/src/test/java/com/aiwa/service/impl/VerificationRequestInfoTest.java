package com.aiwa.service.impl;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.ProviderProfileRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class VerificationRequestInfoTest {

    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final VerificationServiceImpl service = new VerificationServiceImpl(providerRepo, notificationService, mock(WaitlistService.class), mock(BookingServiceImpl.class));

    private ProviderProfile provider() {
        User u = User.builder().id(50L).role(UserRole.PROVIDER).build();
        return ProviderProfile.builder().id(7L).user(u)
                .verificationStatus(VerificationStatus.PENDING_VERIFICATION).build();
    }

    @Test
    void requestMoreInfoNotifiesWithoutRejecting() {
        ProviderProfile p = provider();
        when(providerRepo.findById(7L)).thenReturn(Optional.of(p));

        service.requestMoreInfo(7L, "Please re-upload a clearer selfie");

        assertThat(p.getVerificationStatus()).isEqualTo(VerificationStatus.PENDING_VERIFICATION);
        assertThat(p.getRejectionReason()).contains("selfie");
        verify(notificationService).send(eq(50L), eq(NotificationType.PROVIDER_INFO_REQUESTED),
                any(), any(), any(), any(), any(), any());
    }

    @Test
    void requestMoreInfoRequiresMessage() {
        assertThatThrownBy(() -> service.requestMoreInfo(7L, "  "))
                .isInstanceOf(BusinessException.class);
    }
}
