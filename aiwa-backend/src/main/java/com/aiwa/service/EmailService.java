package com.aiwa.service;

/**
 * Sends a plain-text email. Selected by {@code aiwa.email.provider}:
 * {@code dev-log} (default, logs only) or {@code http} (JSON gateway).
 */
public interface EmailService {
    void send(String to, String subject, String text);
}
