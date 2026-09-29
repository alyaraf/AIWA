package com.aiwa.exception;

/** A BusinessException the client should see as HTTP 409 (e.g. a slot already taken). */
public class ConflictException extends BusinessException {
    public ConflictException(String message) {
        super(message);
    }
}
