package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.AuditLogEntry;
import com.aiwa.repository.AuditLogRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/admin/audit")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Audit log", description = "History of privileged admin actions")
public class AuditController {

    private final AuditLogRepository auditRepo;

    @GetMapping
    @Operation(summary = "List admin audit entries, newest first (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.AuditLogDto>>> list(
            @RequestParam(required = false) String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<AuditLogEntry> result = (query != null && !query.isBlank())
                ? auditRepo.search(query.trim(), pageable)
                : auditRepo.findAllByOrderByCreatedAtDesc(pageable);
        return ResponseEntity.ok(ApiResponse.Success.of(result.map(this::toDto)));
    }

    private ApiResponse.AuditLogDto toDto(AuditLogEntry entry) {
        return ApiResponse.AuditLogDto.builder()
                .id(entry.getId())
                .actor(entry.getActor())
                .action(entry.getAction())
                .target(entry.getTarget())
                .ipAddress(entry.getIpAddress())
                .createdAt(entry.getCreatedAt())
                .build();
    }
}
