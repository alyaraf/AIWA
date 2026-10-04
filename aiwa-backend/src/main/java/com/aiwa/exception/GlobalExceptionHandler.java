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
        // AU-13: "Booking not found with id: 5" reached Arabic users in English. The
        // detail stays in the log; the client gets the translated message and a code.
        log.debug("Not found: {}", ex.getMessage());
        return keyed(HttpStatus.NOT_FOUND, "Not Found", "error.not_found");
    }

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<ApiResponse.Error> handleForbiddenObject(ForbiddenException ex) {
        return keyed(HttpStatus.FORBIDDEN, "Forbidden", ex.getMessage());
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ApiResponse.Error> handleConflict(ConflictException ex) {
        return keyed(HttpStatus.CONFLICT, "Conflict", ex.getMessage());
    }

    @ExceptionHandler(ServiceUnavailableException.class)
    public ResponseEntity<ApiResponse.Error> handleUnavailable(ServiceUnavailableException ex) {
        return keyed(HttpStatus.SERVICE_UNAVAILABLE, "Service Unavailable", ex.getMessage());
    }

    @ExceptionHandler(TooManyRequestsException.class)
    public ResponseEntity<ApiResponse.Error> handleTooMany(TooManyRequestsException ex) {
        return keyed(HttpStatus.TOO_MANY_REQUESTS, "Too Many Requests", ex.getMessage());
    }

    @ExceptionHandler(org.springframework.orm.ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<ApiResponse.Error> handleStaleWrite(org.springframework.orm.ObjectOptimisticLockingFailureException ex) {
        // Someone else changed the same booking/profile first (@Version, BE-38):
        // the client should reload and try again rather than overwrite it.
        return keyed(HttpStatus.CONFLICT, "Conflict", "error.concurrent_update");
    }

    @ExceptionHandler(org.springframework.dao.PessimisticLockingFailureException.class)
    public ResponseEntity<ApiResponse.Error> handleLockTimeout(org.springframework.dao.PessimisticLockingFailureException ex) {
        // Two bookings raced for the same provider calendar and this one lost the
        // row lock — the same outcome for the client as a taken slot.
        return keyed(HttpStatus.CONFLICT, "Conflict", "booking.error.conflict");
    }

    @ExceptionHandler(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiResponse.Error> handleTypeMismatch(
            org.springframework.web.method.annotation.MethodArgumentTypeMismatchException ex) {
        // e.g. ?status=NOT_A_STATUS or a non-numeric id — a client error, not a 500.
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request",
                        "Invalid value for parameter '" + ex.getName() + "'"));
    }

    @ExceptionHandler(org.springframework.web.bind.MissingServletRequestParameterException.class)
    public ResponseEntity<ApiResponse.Error> handleMissingParam(
            org.springframework.web.bind.MissingServletRequestParameterException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request",
                        "Missing required parameter '" + ex.getParameterName() + "'"));
    }

    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse.Error> handleUnreadable(
            org.springframework.http.converter.HttpMessageNotReadableException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request", "Malformed request body"));
    }

    /**
     * M-9: a unique or foreign-key constraint refused the write — typically two
     * identical requests racing (registration, review, ledger row). A 409 the
     * client can reload on, not a 500 that pages operations.
     */
    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<ApiResponse.Error> handleIntegrity(org.springframework.dao.DataIntegrityViolationException ex) {
        log.warn("Constraint violation: {}", ex.getMostSpecificCause().getMessage());
        return keyed(HttpStatus.CONFLICT, "Conflict", "error.duplicate_or_conflict");
    }

    /** M-9: an Optional.orElseThrow() with no message, e.g. the signed-in user no longer exists. */
    @ExceptionHandler(java.util.NoSuchElementException.class)
    public ResponseEntity<ApiResponse.Error> handleNoSuchElement(java.util.NoSuchElementException ex) {
        return keyed(HttpStatus.NOT_FOUND, "Not Found", "error.not_found");
    }

    @ExceptionHandler(org.springframework.web.multipart.support.MissingServletRequestPartException.class)
    public ResponseEntity<ApiResponse.Error> handleMissingPart(
            org.springframework.web.multipart.support.MissingServletRequestPartException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request",
                        "Missing required part '" + ex.getRequestPartName() + "'"));
    }

    @ExceptionHandler(org.springframework.web.multipart.MultipartException.class)
    public ResponseEntity<ApiResponse.Error> handleMultipart(org.springframework.web.multipart.MultipartException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(buildError(HttpStatus.BAD_REQUEST, "Bad Request", "A file upload was expected"));
    }

    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiResponse.Error> handleMediaType(org.springframework.web.HttpMediaTypeNotSupportedException ex) {
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
                .body(buildError(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Unsupported Media Type",
                        "Content type not supported"));
    }

    /** Bean-validation on @RequestParam / @PathVariable (@Min, @Max, @Size on a validated controller). */
    @ExceptionHandler({jakarta.validation.ConstraintViolationException.class,
            org.springframework.web.method.annotation.HandlerMethodValidationException.class})
    public ResponseEntity<ApiResponse.Error> handleParamValidation(Exception ex) {
        return keyed(HttpStatus.BAD_REQUEST, "Validation Failed", "error.invalid_parameter");
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse.Error> handleBusiness(BusinessException ex) {
        // BusinessException carries either a plain English sentence (legacy call
        // sites) or an i18n bundle key (e.g. "booking.error.conflict"); resolving
        // it through MessageHelper translates the ones that have been migrated to
        // a key and passes everything else through unchanged (useCodeAsDefaultMessage
        // means an unknown "key" — i.e. a raw sentence — just returns itself).
        return keyed(HttpStatus.BAD_REQUEST, "Bad Request", ex.getMessage());
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
        // @PreAuthorize refused the caller's role or admin permission.
        return keyed(HttpStatus.FORBIDDEN, "Forbidden", com.aiwa.config.SecurityConfig.ROLE_FORBIDDEN_CODE);
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

    /**
     * An unknown URL (a typo, a bot probe, or the API docs that are switched off
     * in prod) is a 404, not a 500 with an ERROR stack trace in the logs.
     */
    @ExceptionHandler(org.springframework.web.servlet.resource.NoResourceFoundException.class)
    public ResponseEntity<ApiResponse.Error> handleNoRoute(org.springframework.web.servlet.resource.NoResourceFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(buildError(HttpStatus.NOT_FOUND, "Not Found", "No such endpoint"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse.Error> handleGeneral(Exception ex) {
        log.error("Unhandled exception", ex);
        // Every unexpected error lands here rather than escaping to Spring, so
        // report it explicitly (a no-op without SENTRY_DSN).
        io.sentry.Sentry.captureException(ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(buildError(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server Error", "Something went wrong"));
    }

    private static final java.util.regex.Pattern MESSAGE_KEY =
            java.util.regex.Pattern.compile("[a-z0-9_]+(\\.[a-z0-9_]+)+");

    /** Resolves an i18n key (or passes a raw sentence through) and exposes the key as {@code code}. */
    private ResponseEntity<ApiResponse.Error> keyed(HttpStatus status, String error, String keyOrMessage) {
        ApiResponse.Error body = buildError(status, error, messages.get(keyOrMessage));
        if (keyOrMessage != null && MESSAGE_KEY.matcher(keyOrMessage).matches()) {
            body.setCode(keyOrMessage);
        }
        return ResponseEntity.status(status).body(body);
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
