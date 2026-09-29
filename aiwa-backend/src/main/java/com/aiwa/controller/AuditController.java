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

    @GetMapping(value = "/export", produces = "text/csv")
    @Operation(summary = "Export the audit log (optionally filtered by ?query=) as CSV, newest first, max 10 000 rows (ADMIN)")
    public ResponseEntity<String> export(@RequestParam(required = false) String query) {
        Pageable pageable = PageRequest.of(0, 10_000);
        Page<AuditLogEntry> result = (query != null && !query.isBlank())
                ? auditRepo.search(query.trim(), pageable)
                : auditRepo.findAllByOrderByCreatedAtDesc(pageable);
        StringBuilder csv = new StringBuilder("id,createdAt,actor,action,target,ipAddress\n");
        for (AuditLogEntry e : result) {
            csv.append(e.getId()).append(',')
                    .append(e.getCreatedAt() != null ? e.getCreatedAt() : "").append(',')
                    .append(cell(e.getActor())).append(',')
                    .append(cell(e.getAction())).append(',')
                    .append(cell(e.getTarget())).append(',')
                    .append(cell(e.getIpAddress())).append('\n');
        }
        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"audit-log.csv\"")
                .body(csv.toString());
    }

    /**
     * CSV-escape a cell and neutralise spreadsheet formulas: a value starting with
     * = + - @ would otherwise execute when an admin opens the file in Excel
     * (targets and names are user-controlled text).
     */
    static String cell(String v) {
        if (v == null) return "";
        String s = v;
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) s = "'" + s;
        if (s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")) {
            s = "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
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
