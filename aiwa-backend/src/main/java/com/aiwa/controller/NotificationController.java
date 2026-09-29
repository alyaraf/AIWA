package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.NotificationServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/notifications")
@RequiredArgsConstructor
@Tag(name = "Notifications", description = "In-app notification management")
public class NotificationController {

    private final NotificationServiceImpl notificationService;
    private final UserRepository userRepo;

    @GetMapping
    @Operation(summary = "Get my notifications (paginated)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.NotificationDto>>> getMyNotifications(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                notificationService.getMyNotifications(resolveUserId(userDetails),
                        PageRequest.of(page, size))));
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Get unread notification count")
    public ResponseEntity<ApiResponse.Success<Long>> unreadCount(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                notificationService.countUnread(resolveUserId(userDetails))));
    }

    @PostMapping("/mark-all-read")
    @Operation(summary = "Mark all notifications as read")
    public ResponseEntity<ApiResponse.Success<Void>> markAllRead(
            @AuthenticationPrincipal UserDetails userDetails) {
        notificationService.markAllRead(resolveUserId(userDetails));
        return ResponseEntity.ok(ApiResponse.Success.of("All notifications marked as read", null));
    }

    /**
     * Mark one notification read. PATCH is the documented verb; PUT is accepted
     * too because the shipped mobile builds call PUT /notifications/{id}/read.
     */
    @RequestMapping(value = "/{id}/read", method = {RequestMethod.PATCH, RequestMethod.PUT})
    @Operation(summary = "Mark one of my notifications as read")
    public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationDto>> markRead(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Notification marked as read",
                notificationService.markRead(resolveUserId(userDetails), id)));
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
