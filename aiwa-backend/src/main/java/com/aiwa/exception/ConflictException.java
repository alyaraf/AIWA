package com.aiwa.exception;

/**
 * The request is valid but collides with current state — most importantly a
 * booking slot that someone else already holds. Maps to 409 so clients can
 * branch on the status code (and the error {@code code}) instead of matching
 * translated message text.
 */
public class ConflictException extends BusinessException {
    public ConflictException(String message) {
        super(message);
    }
}
