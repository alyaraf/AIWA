package com.aiwa.exception;

/** A per-identity rate limit (e.g. OTP sends per phone) was exceeded. Maps to 429. */
public class TooManyRequestsException extends BusinessException {
    public TooManyRequestsException(String message) {
        super(message);
    }
}
