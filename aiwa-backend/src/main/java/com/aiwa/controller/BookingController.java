package com.aiwa.controller;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.request.RescheduleRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.BookingService;
import com.aiwa.service.impl.BookingServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/bookings")
@RequiredArgsConstructor
@Tag(name = "Bookings", description = "Booking creation, tracking and management")
public class BookingController {

    private final BookingServiceImpl bookingService;
    private final UserRepository userRepo;

    @PostMapping
    @Operation(summary = "Create a booking — SCHEDULED or BOOK_NOW (CUSTOMER). "
            + "Pass a client-generated Idempotency-Key header (e.g. one UUID per tap of "
            + "\"Book\") so a retry or double-tap returns the original booking instead of "
            + "creating a duplicate; even without one, an identical request from the same "
            + "customer within a few seconds is still deduplicated automatically.")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> create(
            @Valid @RequestBody BookingRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Booking created",
                        bookingService.create(resolveUserId(userDetails), request, idempotencyKey)));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get booking by ID")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> getById(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                bookingService.getById(id, resolveUserId(userDetails))));
    }

    @GetMapping("/my")
    @Operation(summary = "Get current customer's bookings")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> myBookings(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                bookingService.getMyBookings(resolveUserId(userDetails), PageRequest.of(page, size))));
    }

    @GetMapping("/provider")
    @Operation(summary = "Get all bookings for the authenticated provider")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> providerBookings(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                bookingService.getProviderBookings(resolveUserId(userDetails), PageRequest.of(page, size))));
    }

    // ── Gap 8: Split status updates by semantic action ─────────────────────────

    @PatchMapping("/{id}/accept")
    @Operation(summary = "Provider accepts a pending booking")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> accept(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Booking accepted",
                bookingService.updateStatus(resolveUserId(userDetails), id, BookingStatus.ACCEPTED)));
    }

    @PatchMapping("/{id}/cancel")
    @Operation(summary = "Cancel a booking (customer or provider) with reason")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> cancel(
            @PathVariable Long id,
            @RequestParam(required = false) String reason,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        ApiResponse.BookingDto dto = bookingService.updateStatus(userId, id, BookingStatus.CANCELLED);
        return ResponseEntity.ok(ApiResponse.Success.of("Booking cancelled", dto));
    }

    // ── Gap 4: Reject with reason and return alternative providers ─────────────

    @PatchMapping("/{id}/reject")
    @Operation(summary = "Provider rejects booking with reason + returns alternative providers")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingWithAlternativesDto>> reject(
            @PathVariable Long id,
            @RequestParam String reason,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Booking rejected",
                bookingService.rejectWithAlternatives(resolveUserId(userDetails), id, reason)));
    }

    @PatchMapping("/{id}/on-the-way")
    @Operation(summary = "Provider marks ON_THE_WAY")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> onTheWay(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Status updated",
                bookingService.updateStatus(resolveUserId(userDetails), id, BookingStatus.ON_THE_WAY)));
    }

    @PatchMapping("/{id}/arrived")
    @Operation(summary = "Provider marks ARRIVED")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> arrived(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Status updated",
                bookingService.updateStatus(resolveUserId(userDetails), id, BookingStatus.ARRIVED)));
    }

    @PatchMapping("/{id}/in-progress")
    @Operation(summary = "Provider marks IN_PROGRESS")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> inProgress(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Status updated",
                bookingService.updateStatus(resolveUserId(userDetails), id, BookingStatus.IN_PROGRESS)));
    }

    @PatchMapping("/{id}/complete")
    @Operation(summary = "Provider marks booking COMPLETED — cashCollected=false flags it DISPUTED")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> complete(
            @PathVariable Long id,
            @RequestParam(defaultValue = "true") boolean cashCollected,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Booking completed",
                bookingService.complete(resolveUserId(userDetails), id, cashCollected)));
    }

    @PatchMapping("/{id}/no-show")
    @Operation(summary = "Provider marks booking as NO_SHOW (customer did not attend)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> noShow(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Marked as no-show",
                bookingService.updateStatus(resolveUserId(userDetails), id, BookingStatus.NO_SHOW)));
    }

    @PatchMapping("/{id}/reschedule")
    @Operation(summary = "Customer reschedules a booking to a new date/time")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> reschedule(
            @PathVariable Long id,
            @Valid @RequestBody RescheduleRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Booking rescheduled",
                bookingService.reschedule(resolveUserId(userDetails), id, request)));
    }

    @PatchMapping("/{id}/propose-time")
    @Operation(summary = "Provider proposes an alternative slot for a PENDING booking")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> proposeTime(
            @PathVariable Long id,
            @Valid @RequestBody RescheduleRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Alternative time proposed",
                bookingService.proposeReschedule(resolveUserId(userDetails), id, request)));
    }

    @PatchMapping("/{id}/proposal-response")
    @Operation(summary = "Customer accepts or declines the provider-proposed time")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> proposalResponse(
            @PathVariable Long id,
            @RequestParam boolean accept,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                accept ? "Proposed time accepted" : "Proposed time declined",
                bookingService.respondToProposal(resolveUserId(userDetails), id, accept)));
    }

    @PatchMapping("/{id}/check-in")
    @Operation(summary = "Customer checks in at an on-site (venue) booking")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> checkIn(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Checked in",
                bookingService.checkIn(resolveUserId(userDetails), id)));
    }

    @PatchMapping("/{id}/confirm-payment")
    @Operation(summary = "Customer confirms cash paid (paid=true) or reports unpaid/disputed (paid=false)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> confirmPayment(
            @PathVariable Long id,
            @RequestParam boolean paid,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                paid ? "Payment confirmed" : "Payment reported as unpaid/disputed",
                bookingService.confirmPayment(resolveUserId(userDetails), id, paid)));
    }

    @GetMapping("/slots")
    @Operation(summary = "Get available time slots for a provider + service on a date")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.TimeSlotDto>>> slots(
            @RequestParam Long providerId,
            @RequestParam Long serviceId,
            @RequestParam(required = false) Long staffMemberId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                bookingService.getAvailableSlots(providerId, serviceId, staffMemberId, date)));
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
