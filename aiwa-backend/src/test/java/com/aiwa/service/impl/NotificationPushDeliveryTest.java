package com.aiwa.service.impl;

import com.aiwa.entity.User;
import com.aiwa.enums.DevicePlatform;
import com.aiwa.enums.Language;
import com.aiwa.enums.NotificationType;
import com.aiwa.repository.NotificationRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.PushNotificationService;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * The last mile: a notification that's allowed to push AND has a registered
 * device token actually gets handed to the push provider, in the user's
 * preferred language. Before the User.pushToken column existed there was
 * nothing to check here — this is the behavior the missing column blocked.
 */
class NotificationPushDeliveryTest {

    private final NotificationRepository notificationRepo = mock(NotificationRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final PushNotificationService pushService = mock(PushNotificationService.class);
    private final PushDeviceService pushDevices = mock(PushDeviceService.class);

    private final NotificationServiceImpl service =
            new NotificationServiceImpl(notificationRepo, userRepo, pushService, pushDevices);

    private void devices(com.aiwa.entity.PushDevice... ds) {
        when(pushDevices.devicesOf(1L)).thenReturn(java.util.List.of(ds));
    }

    private static com.aiwa.entity.PushDevice device(String token, DevicePlatform platform) {
        return com.aiwa.entity.PushDevice.builder().token(token).platform(platform).build();
    }

    @Test
    void sendsPushInArabicWhenThatsThePreferredLanguageAndATokenIsRegistered() {
        User user = User.builder().id(1L).notifyPush(true).muteAll(false)
                .preferredLanguage(Language.AR)
                .build();
        devices(device("device-token", DevicePlatform.ANDROID));
        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(notificationRepo.save(any())).thenAnswer(inv -> {
            var n = inv.getArgument(0, com.aiwa.entity.Notification.class);
            n.setId(42L);
            return n;
        });

        service.send(1L, NotificationType.BOOKING_CREATED, "New booking", "حجز جديد",
                "body en", "نص عربي", 7L, 9L);

        verify(pushService).send(eq("device-token"), eq(DevicePlatform.ANDROID),
                eq("حجز جديد"), eq("نص عربي"), any());
    }

    @Test
    void fallsBackToEnglishWhenNoArabicTextIsSupplied() {
        User user = User.builder().id(1L).notifyPush(true).muteAll(false)
                .preferredLanguage(Language.AR)
                .build();
        devices(device("device-token", null));
        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(notificationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.send(1L, NotificationType.BOOKING_CREATED, "New booking", null, "body en", null, null, null);

        verify(pushService).send(eq("device-token"), any(), eq("New booking"), eq("body en"), any());
    }

    @Test
    void doesNotAttemptDeliveryWhenNoDeviceTokenIsRegistered() {
        User user = User.builder().id(1L).notifyPush(true).muteAll(false).build(); // no pushToken
        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(notificationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.send(1L, NotificationType.BOOKING_CREATED, "t", "t", "b", "b", null, null);

        verifyNoInteractions(pushService);
    }

    @Test
    void pushesToEveryRegisteredPhone() {
        User user = User.builder().id(1L).notifyPush(true).muteAll(false).build();
        devices(device("phone-a", DevicePlatform.ANDROID), device("phone-b", DevicePlatform.IOS));
        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(notificationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.send(1L, NotificationType.BOOKING_CREATED, "t", "t", "b", "b", null, null);

        verify(pushService).send(eq("phone-a"), eq(DevicePlatform.ANDROID), any(), any(), any());
        verify(pushService).send(eq("phone-b"), eq(DevicePlatform.IOS), any(), any(), any());
    }

    @Test
    void respectsMuteAllEvenWithATokenRegistered() {
        User user = User.builder().id(1L).notifyPush(true).muteAll(true).build();
        devices(device("device-token", DevicePlatform.ANDROID));
        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(notificationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.send(1L, NotificationType.BOOKING_CREATED, "t", "t", "b", "b", null, null);

        verifyNoInteractions(pushService);
    }
}
