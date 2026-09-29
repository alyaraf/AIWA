package com.aiwa.dto.request;

import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalTime;

/** Notification preferences: channel toggles + quiet hours. All fields optional (partial update). */
@Data
public class UpdateNotificationPreferencesRequest {
    private Boolean notifyPush;
    private Boolean notifyEmail;
    private Boolean notifySms;
    private Boolean notifyWhatsapp;
    private Boolean muteAll;

    @DateTimeFormat(pattern = "HH:mm")
    private LocalTime quietHoursStart;

    @DateTimeFormat(pattern = "HH:mm")
    private LocalTime quietHoursEnd;

    /** Explicitly clear the quiet-hours window (start/end set to null). */
    private Boolean clearQuietHours;
}
