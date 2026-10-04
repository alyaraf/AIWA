package com.aiwa.controller;

import com.aiwa.dto.request.ChatMessageRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.AuditService;
import com.aiwa.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Closes the gap the flow doc described but nothing implemented: a customer or
 * provider can report an abusive chat message, and support can remove it —
 * once removed, both parties see a fixed placeholder instead of the original text.
 */
class ChatControllerModerationTest {

    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final ChatMessageRepository chatRepo = mock(ChatMessageRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final ModerationCaseRepository moderationRepo = mock(ModerationCaseRepository.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final AuditService auditService = mock(AuditService.class);

    private final ChatController controller =
            new ChatController(bookingRepo, chatRepo, userRepo, moderationRepo, notificationService, auditService);

    private User customer = User.builder().id(1L).fullName("Nour").email("nour@x.com").role(UserRole.CUSTOMER).build();
    private User providerUser = User.builder().id(2L).fullName("Nadia").email("nadia@x.com").role(UserRole.PROVIDER).build();
    private ProviderProfile provider = ProviderProfile.builder().id(9L).user(providerUser).build();
    private Booking booking = Booking.builder().id(5L).customer(customer).provider(provider).build();

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    @Test
    void reportCreatesAnOpenModerationCase() {
        when(bookingRepo.findById(5L)).thenReturn(Optional.of(booking));
        when(userRepo.findByLogin("nour@x.com")).thenReturn(Optional.of(customer));
        when(chatRepo.findById(11L)).thenReturn(Optional.of(
                ChatMessage.builder().id(11L).booking(booking).sender(providerUser)
                        .type(ChatMessageType.TEXT).message("give me your number off the app").build()));

        controller.report(5L, 11L, "asking to go off-platform", principal("nour@x.com"));

        verify(moderationRepo).save(argThat(c ->
                c.getTargetType() == ModerationTargetType.CHAT_MESSAGE
                        && c.getTargetId().equals(11L)
                        && "asking to go off-platform".equals(c.getReason())));
        verify(auditService).record(eq("CHAT_MESSAGE_REPORTED"), contains("11"));
    }

    @Test
    void reportRejectsAMessageFromAnUnrelatedBooking() {
        when(bookingRepo.findById(5L)).thenReturn(Optional.of(booking));
        when(userRepo.findByLogin("nour@x.com")).thenReturn(Optional.of(customer));
        when(chatRepo.findById(11L)).thenReturn(Optional.of(
                ChatMessage.builder().id(11L).booking(Booking.builder().id(999L).build())
                        .sender(providerUser).message("x").build()));

        assertThatThrownBy(() -> controller.report(5L, 11L, "reason", principal("nour@x.com")))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void nonPartyCannotReportOrReadTheThread() {
        when(bookingRepo.findById(5L)).thenReturn(Optional.of(booking));
        User stranger = User.builder().id(999L).email("stranger@x.com").role(UserRole.CUSTOMER).build();
        when(userRepo.findByLogin("stranger@x.com")).thenReturn(Optional.of(stranger));

        assertThatThrownBy(() -> controller.list(5L, null, principal("stranger@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("access_denied");
    }

    @Test
    void listRedactsRemovedMessagesForBothParties() {
        when(bookingRepo.findById(5L)).thenReturn(Optional.of(booking));
        when(userRepo.findByLogin("nour@x.com")).thenReturn(Optional.of(customer));
        when(chatRepo.findByBookingIdOrderByCreatedAtAsc(5L)).thenReturn(List.of(
                ChatMessage.builder().id(1L).booking(booking).sender(providerUser).type(ChatMessageType.TEXT)
                        .message("hello").removed(false).build(),
                ChatMessage.builder().id(2L).booking(booking).sender(providerUser).type(ChatMessageType.TEXT)
                        .message("abusive text").removed(true).build()
        ));

        List<ApiResponse.ChatMessageDto> rows = controller.list(5L, null, principal("nour@x.com")).getBody().getData();

        assertThat(rows.get(0).getMessage()).isEqualTo("hello");
        assertThat(rows.get(1).isRemoved()).isTrue();
        assertThat(rows.get(1).getMessage()).isEqualTo("[message removed by admin]");
    }

    @Test
    void resolveRemoveRedactsMessageAndActionsCase() {
        ModerationCase c = ModerationCase.builder().id(1L).targetType(ModerationTargetType.CHAT_MESSAGE)
                .targetId(11L).status(ModerationStatus.OPEN).build();
        ChatMessage message = ChatMessage.builder().id(11L).booking(booking).sender(providerUser)
                .type(ChatMessageType.TEXT).message("bad text").removed(false).build();
        when(moderationRepo.findById(1L)).thenReturn(Optional.of(c));
        when(chatRepo.findById(11L)).thenReturn(Optional.of(message));

        controller.resolveReported(1L, "REMOVE");

        assertThat(message.isRemoved()).isTrue();
        verify(chatRepo).save(message);
        assertThat(c.getStatus()).isEqualTo(ModerationStatus.ACTIONED);
        verify(auditService).record(eq("CHAT_MESSAGE_REMOVED"), contains("11"));
    }

    @Test
    void resolveKeepDismissesWithoutRedacting() {
        ModerationCase c = ModerationCase.builder().id(2L).targetType(ModerationTargetType.CHAT_MESSAGE)
                .targetId(12L).status(ModerationStatus.OPEN).build();
        when(moderationRepo.findById(2L)).thenReturn(Optional.of(c));

        controller.resolveReported(2L, "keep");

        verify(chatRepo, never()).save(any());
        assertThat(c.getStatus()).isEqualTo(ModerationStatus.DISMISSED);
    }
}
