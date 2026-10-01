package com.aiwa.exception;

/** A dependency needed to answer safely (e.g. Redis for token revocation) is down. Maps to 503; retry shortly. */
public class ServiceUnavailableException extends BusinessException {
    public ServiceUnavailableException(String message) {
        super(message);
    }
}
