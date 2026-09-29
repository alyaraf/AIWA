package com.aiwa.exception;

import com.aiwa.dto.response.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AccountStatusException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import java.time.LocalDateTime;
import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
@lombok.RequiredArgsConstructor
public class GlobalExceptionHandler {

    private final com.aiwa.i18n.MessageHelper messages;

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiResponse.Error> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(buildError(HttpStatus.NOT_FOUND, "Not Found", ex.getMessage()));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse.Error> handleBusiness(BusinessException ex) {
        // BusinessException carries either a plain English sentence (legacy call
        // sites) or an i18n bundle key (e.g. "booking.error.conflict"); resolving
        // it through MessageHelper translates the ones that have been migrated to
        // a key and passes everything else through unchanged (useCodeAsDefaultMessage
        // means an unknown "key" — i.e. a raw sentence — just returns itself).
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request", messages.get(ex.getMessage())));
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ApiResponse.Error> handleConflict(ConflictException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(buildError(HttpStatus.CONFLICT, "Conflict", messages.get(ex.getMessage())));
    }

    @ExceptionHandler(InvalidTokenException.class)
    public ResponseEntity<ApiResponse.Error> handleInvalidToken(InvalidTokenException ex) {
        // Distinct from a generic BusinessException so mobile/web clients can
        // tell "your session is dead, show the login screen" (401) apart from an
        // ordinary validation failure (400) using the status code alone.
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(buildError(HttpStatus.UNAUTHORIZED, "Unauthorized", messages.get(ex.getMessage())));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiResponse.Error> handleUploadTooLarge(MaxUploadSizeExceededException ex) {
        // Spring rejects an oversized multipart body before it reaches the
        // controller/FileStorageService validation, so without this handler it
        // fell into the generic 500 below with no useful message for the app.
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                .body(buildError(HttpStatus.PAYLOAD_TOO_LARGE, "Payload Too Large",
                        messages.get("upload.error.too_large")));
    }

    @ExceptionHandler(AccountStatusException.class)
    public ResponseEntity<ApiResponse.Error> handleAccountStatus(AccountStatusException ex) {
        return ResponseEntity.status(HttpStatus.LOCKED)
                .body(buildError(HttpStatus.LOCKED, "Locked", messages.get("auth.error.account_disabled")));
    }
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ApiResponse.Error> handleBadCredentials(BadCredentialsException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(buildError(HttpStatus.UNAUTHORIZED, "Unauthorized", messages.get("auth.error.invalid_credentials")));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiResponse.Error> handleAccessDenied(AccessDeniedException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(buildError(HttpStatus.FORBIDDEN, "Forbidden",
                        "You don't have permission to perform this action."));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse.Error> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex) {
        // Most commonly a browser GET landing directly on a POST-only endpoint
        // like /auth/login (e.g. someone pasting the API URL into the address
        // bar) — that's a 405, not an unhandled-exception 500.
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .body(buildError(HttpStatus.METHOD_NOT_ALLOWED, "Method Not Allowed", ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse.Error> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Validation Error", msg));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse.Error> handleGeneral(Exception ex) {
        log.error("Unhandled exception", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(buildError(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server Error", "Something went wrong"));
    }

    private ApiResponse.Error buildError(HttpStatus status, String error, String message) {
        return ApiResponse.Error.builder()
                .success(false)
                .status(status.value())
                .error(error)
                .message(message)
                .timestamp(LocalDateTime.now())
                .build();
    }
}
