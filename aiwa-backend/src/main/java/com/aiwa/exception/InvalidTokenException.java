package com.aiwa.exception;

/**
 * A refresh (or access) token is missing, malformed, expired, blacklisted, or
 * belongs to a now-deactivated account. Mapped to 401 so mobile/web clients can
 * reliably tell "drop tokens and show the login screen" apart from a generic
 * 400 validation failure.
 */
public class InvalidTokenException extends RuntimeException {
    public InvalidTokenException(String message) {
        super(message);
    }
}
