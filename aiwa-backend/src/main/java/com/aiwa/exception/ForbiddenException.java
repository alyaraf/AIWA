package com.aiwa.exception;

/**
 * The caller is authenticated but is not allowed to touch this object (not a
 * party to the booking, not the owner of the address, ...). Maps to 403.
 * Extends BusinessException so existing callers/tests that catch the parent
 * type keep working.
 */
public class ForbiddenException extends BusinessException {
    public ForbiddenException(String message) {
        super(message);
    }
}
