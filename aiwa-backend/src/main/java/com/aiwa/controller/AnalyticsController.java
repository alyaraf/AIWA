package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.enums.BookingStatus;
import com.aiwa.repository.BookingRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;

@RestController
@RequestMapping("/admin/analytics")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin Analytics", description = "Dashboard time-series and exports")
public class AnalyticsController {

    private final BookingRepository bookingRepo;

    @GetMapping("/bookings")
    @Operation(summary = "Daily booking counts (completed / cancelled / total) for the last N days (ADMIN)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.BookingAnalyticsPointDto>>> bookings(
            @RequestParam(defaultValue = "14") int days) {
        return ResponseEntity.ok(ApiResponse.Success.of(series(Math.max(1, Math.min(days, 90)))));
    }

    @GetMapping(value = "/export", produces = "text/csv")
    @Operation(summary = "Export the daily booking series as CSV (ADMIN)")
    public ResponseEntity<String> export(@RequestParam(defaultValue = "30") int days) {
        StringBuilder csv = new StringBuilder("date,completed,cancelled,total\n");
        series(Math.max(1, Math.min(days, 365))).forEach(point -> csv
                .append(point.getDate()).append(',')
                .append(point.getCompleted()).append(',')
                .append(point.getCancelled()).append(',')
                .append(point.getTotal()).append('\n'));
        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"aiwa-bookings.csv\"")
                .body(csv.toString());
    }

    /** Builds a zero-filled per-day series so the chart always has one point per day. */
    private List<ApiResponse.BookingAnalyticsPointDto> series(int days) {
        LocalDate today = LocalDate.now();
        LocalDate from = today.minusDays(days - 1L);

        Map<LocalDate, long[]> byDate = new HashMap<>(); // [completed, cancelled, total]
        for (Object[] row : bookingRepo.countByDateAndStatus(from)) {
            LocalDate date = (LocalDate) row[0];
            BookingStatus status = (BookingStatus) row[1];
            long count = ((Number) row[2]).longValue();
            long[] bucket = byDate.computeIfAbsent(date, key -> new long[3]);
            bucket[2] += count;
            if (status == BookingStatus.COMPLETED) bucket[0] += count;
            else if (status == BookingStatus.CANCELLED || status == BookingStatus.NO_SHOW) bucket[1] += count;
        }

        List<ApiResponse.BookingAnalyticsPointDto> series = new ArrayList<>();
        for (int i = 0; i < days; i++) {
            LocalDate date = from.plusDays(i);
            long[] bucket = byDate.getOrDefault(date, new long[3]);
            series.add(ApiResponse.BookingAnalyticsPointDto.builder()
                    .date(date).completed(bucket[0]).cancelled(bucket[1]).total(bucket[2]).build());
        }
        return series;
    }
}
