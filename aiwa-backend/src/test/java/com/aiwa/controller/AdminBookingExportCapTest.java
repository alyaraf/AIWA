package com.aiwa.controller;

import com.aiwa.config.MessageSourceConfig;
import com.aiwa.entity.Booking;
import com.aiwa.exception.GlobalExceptionHandler;
import com.aiwa.i18n.MessageHelper;
import com.aiwa.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** The bookings export is refused past its cap with a readable message, instead of a file cut off at row 10 000. */
class AdminBookingExportCapTest {

    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final MockMvc mvc = MockMvcBuilders
            .standaloneSetup(new AdminController(mock(UserRepository.class), mock(ProviderProfileRepository.class),
                    bookingRepo, mock(ComplaintRepository.class), mock(ReviewRepository.class),
                    mock(CommissionLedgerRepository.class), mock(SafetyEventRepository.class)))
            .setControllerAdvice(new GlobalExceptionHandler(new MessageHelper(new MessageSourceConfig().messageSource())))
            .build();

    private void matches(long total) {
        when(bookingRepo.adminSearch(any(), anyBoolean(), any(), any()))
                .thenReturn(new PageImpl<Booking>(List.of(), PageRequest.of(0, AdminController.EXPORT_MAX_ROWS), total));
    }

    @Test
    void pastTheCapTheExportIsRefusedWithTheReason() throws Exception {
        matches(AdminController.EXPORT_MAX_ROWS + 1);
        mvc.perform(get("/admin/bookings/export").header("Accept-Language", "en"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("admin.error.export_too_large"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("10,000")));
    }

    @Test
    void atTheCapItIsStillACsvFile() throws Exception {
        matches(AdminController.EXPORT_MAX_ROWS);
        mvc.perform(get("/admin/bookings/export"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(header().string("Content-Disposition", "attachment; filename=aiwa-bookings.csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("ref,customer,")));
    }
}
