package com.aiwa.dto.request;

import jakarta.validation.constraints.Email;
import lombok.Data;

import java.util.List;

/**
 * Admin edit for support settings. When {@code numbers} is non-null it replaces
 * the stored list wholesale; a null {@code numbers} leaves the lines untouched.
 * Every other null field is likewise left unchanged.
 */
@Data
public class SupportSettingsRequest {

    private List<Line> numbers;

    private String availabilityHoursEn;
    private String availabilityHoursAr;

    @Email(message = "Escalation email must be a valid email address")
    private String supportEmail;

    /** Master switch for the WhatsApp support channel. */
    private Boolean whatsappEnabled;

    @Data
    public static class Line {
        private String label;
        private String number;
        private String displayNumber;
        private boolean primary;
        private boolean enabled = true;
    }
}
