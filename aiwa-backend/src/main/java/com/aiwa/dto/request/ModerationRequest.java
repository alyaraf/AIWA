package com.aiwa.dto.request;

import com.aiwa.enums.ModerationTargetType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ModerationRequest {
    @NotNull
    private ModerationTargetType targetType;
    @NotNull
    private Long targetId;
    @Size(max = 1000)
    private String reason;
    @Size(max = 1000)
    private String adminNotes;
}
