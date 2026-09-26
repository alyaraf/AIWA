package com.aiwa.service;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.request.RescheduleRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.enums.BookingStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.List;

public interface BookingService {
    ApiResponse.BookingDto create(Long customerId, BookingRequest request);
    ApiResponse.BookingDto getById(Long bookingId, Long requesterId);
    Page<ApiResponse.BookingDto> getMyBookings(Long customerId, Pageable pageable);
    Page<ApiResponse.BookingDto> getProviderBookings(Long userId, Pageable pageable);
    ApiResponse.BookingDto updateStatus(Long userId, Long bookingId, BookingStatus status);
    List<ApiResponse.TimeSlotDto> getAvailableSlots(Long providerId, Long serviceId, Long staffMemberId, LocalDate date);
    ApiResponse.BookingWithAlternativesDto rejectWithAlternatives(Long userId, Long bookingId, String reason);
    ApiResponse.BookingDto reschedule(Long customerId, Long bookingId, RescheduleRequest request);
    ApiResponse.BookingDto complete(Long userId, Long bookingId, boolean cashCollected);
    ApiResponse.BookingDto proposeReschedule(Long providerUserId, Long bookingId, RescheduleRequest request);
    ApiResponse.BookingDto respondToProposal(Long customerId, Long bookingId, boolean accept);
    ApiResponse.BookingDto confirmPayment(Long customerId, Long bookingId, boolean paid);
    ApiResponse.BookingDto checkIn(Long customerId, Long bookingId);
    ApiResponse.BookingDto adminForceCancel(Long bookingId, String reason);
    ApiResponse.BookingDto adminResolveDispute(Long bookingId, boolean paid);
    ApiResponse.BookingDto adminResolveDispute(Long bookingId, String outcome);
}
