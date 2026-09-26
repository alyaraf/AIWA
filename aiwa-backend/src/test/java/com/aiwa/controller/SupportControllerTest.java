package com.aiwa.controller;

import com.aiwa.dto.request.SupportSettingsRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.SupportNumber;
import com.aiwa.entity.SupportSettings;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.SupportSettingsRepository;
import com.aiwa.service.impl.AuditService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class SupportControllerTest {

    private final SupportSettingsRepository supportRepo = mock(SupportSettingsRepository.class);
    private final AuditService auditService = mock(AuditService.class);
    private final SupportController controller = new SupportController(supportRepo, auditService);

    @BeforeEach
    void setUp() {
        when(supportRepo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(
                SupportSettings.builder().id(1L).whatsappNumber("").whatsappNumberDisplay("")
                        .whatsappEnabled(true).numbers(new ArrayList<>()).build()));
        when(supportRepo.save(any(SupportSettings.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private SupportSettingsRequest.Line line(String label, String number, boolean primary, boolean enabled) {
        SupportSettingsRequest.Line l = new SupportSettingsRequest.Line();
        l.setLabel(label); l.setNumber(number); l.setPrimary(primary); l.setEnabled(enabled);
        return l;
    }

    private SupportSettingsRequest req(SupportSettingsRequest.Line... lines) {
        SupportSettingsRequest r = new SupportSettingsRequest();
        r.setNumbers(new ArrayList<>(List.of(lines)));
        return r;
    }

    @Test
    void forcesExactlyOnePrimaryAndMirrorsToLegacyFields() {
        var body = controller.adminUpdate(req(
                line("General", "+201000000001", true, true),
                line("Payments", "+201000000002", true, true))) // both marked primary
                .getBody().getData();

        List<ApiResponse.SupportNumberDto> nums = body.getNumbers();
        assertThat(nums).hasSize(2);
        assertThat(nums.stream().filter(ApiResponse.SupportNumberDto::isPrimary).count()).isEqualTo(1);
        assertThat(nums.get(0).isPrimary()).isTrue();
        // legacy fields mirror the primary
        assertThat(body.getWhatsappNumber()).isEqualTo("+201000000001");
    }

    @Test
    void picksFirstEnabledWhenNoneMarkedPrimary() {
        var body = controller.adminUpdate(req(
                line("Disabled", "+201000000009", false, false),
                line("Live", "+201000000010", false, true)))
                .getBody().getData();
        assertThat(body.getNumbers().stream().filter(ApiResponse.SupportNumberDto::isPrimary).map(ApiResponse.SupportNumberDto::getNumber))
                .containsExactly("+201000000010");
    }

    @Test
    void rejectsWhenNoEnabledNumber() {
        assertThatThrownBy(() -> controller.adminUpdate(req(
                line("Off", "+201000000001", true, false))))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("enabled");
    }

    @Test
    void rejectsWhenAllNumbersBlank() {
        assertThatThrownBy(() -> controller.adminUpdate(req(line("x", "  ", true, true))))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("at least one");
    }

    @Test
    void nullNumbersLeavesLinesUntouchedButUpdatesHours() {
        when(supportRepo.findFirstByOrderByIdAsc()).thenReturn(Optional.of(
                SupportSettings.builder().id(1L).whatsappNumber("+20100").whatsappEnabled(true)
                        .numbers(new ArrayList<>(List.of(SupportNumber.builder()
                                .label("General").number("+20100").displayNumber("+20 100")
                                .primary(true).enabled(true).build()))).build()));

        SupportSettingsRequest r = new SupportSettingsRequest();
        r.setNumbers(null);
        r.setAvailabilityHoursEn("Daily 9-5");

        var body = controller.adminUpdate(r).getBody().getData();
        assertThat(body.getNumbers()).hasSize(1);
        assertThat(body.getAvailabilityHoursEn()).isEqualTo("Daily 9-5");
    }
}
