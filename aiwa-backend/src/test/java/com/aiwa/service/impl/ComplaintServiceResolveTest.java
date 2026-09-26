package com.aiwa.service.impl;

import com.aiwa.entity.Complaint;
import com.aiwa.entity.User;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ComplaintRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * GET /admin/flags lists purely by Complaint.flagged=true, with no regard for
 * status — so resolving a complaint (whether via "Dismiss", "Send warning" or
 * "Suspend / ban" on the Flags screen) must also clear the flag, or the same
 * row reappears on the very next refresh even though an admin already acted
 * on it.
 */
class ComplaintServiceResolveTest {

    private final ComplaintRepository complaintRepo = mock(ComplaintRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);

    private final ComplaintServiceImpl service =
            new ComplaintServiceImpl(complaintRepo, userRepo, bookingRepo, providerRepo);

    @Test
    void resolvingAFlaggedComplaintClearsTheFlag() {
        Complaint c = Complaint.builder().id(1L).reporter(User.builder().id(1L).fullName("Yara").build())
                .status(ComplaintStatus.ESCALATED).flagged(true).category("ABUSE").description("x").build();
        when(complaintRepo.findById(1L)).thenReturn(Optional.of(c));
        when(complaintRepo.save(any(Complaint.class))).thenAnswer(inv -> inv.getArgument(0));

        var dto = service.resolve(1L, 9L, "Suspended the provider");

        assertThat(c.isFlagged()).isFalse();
        assertThat(c.getStatus()).isEqualTo(ComplaintStatus.RESOLVED);
        assertThat(dto.isFlagged()).isFalse();
    }
}
