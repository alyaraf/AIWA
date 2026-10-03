package com.aiwa.api;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.*;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.SmsService;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CR-06: the provider's "I paid" report freezes the entries and the total;
 * finance confirms exactly that total, and commission recorded afterwards
 * stays owed.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PayoutReportFreezeTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired CommissionLedgerRepository ledgerRepo;
    @Autowired PasswordEncoder encoder;
    @MockBean SmsService smsService;

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("payout " + n).email("payout" + n + "@freeze.aiwa")
                .phone("+2010777" + String.format("%05d", n)).password(encoder.encode(PASSWORD))
                .role(role).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new HashSet<>()
                        : new HashSet<>(EnumSet.copyOf(java.util.List.of(perms))))
                .build());
    }

    private ProviderProfile provider(User owner) {
        return providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Freeze Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
    }

    private long entry(ProviderProfile p, String commission, LedgerEntryStatus status) {
        return ledgerRepo.save(CommissionLedgerEntry.builder().provider(p)
                .bookingAmount(new BigDecimal(commission).multiply(BigDecimal.TEN))
                .commissionPercent(BigDecimal.TEN).commissionAmount(new BigDecimal(commission))
                .status(status).build()).getId();
    }

    private String bearer(User u) throws Exception {
        String body = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return "Bearer " + json.readTree(body).get("data").get("accessToken").asText();
    }

    private LedgerEntryStatus statusOf(long entryId) {
        return ledgerRepo.findById(entryId).orElseThrow().getStatus();
    }

    @Test
    void confirmSettlesOnlyWhatTheProviderReported() throws Exception {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = provider(owner);
        String providerAuth = bearer(owner);
        String finance = bearer(user(UserRole.ADMIN, AdminPermission.FINANCE));
        long a = entry(p, "30", LedgerEntryStatus.DUE);
        long b = entry(p, "20", LedgerEntryStatus.OVERDUE);

        mvc.perform(patch("/provider/settlement/pay").header("Authorization", providerAuth))
                .andExpect(status().isOk());

        // A booking completes after the report: new commission becomes due.
        long later = entry(p, "45", LedgerEntryStatus.DUE);

        // A second report while the first is waiting is refused, in the caller's language.
        mvc.perform(patch("/provider/settlement/pay").header("Authorization", providerAuth))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("settlement.error.report_pending"))
                .andExpect(jsonPath("$.message").value("You already reported a payment. Please wait for AIWA finance to confirm it"));
        mvc.perform(patch("/provider/settlement/pay").header("Authorization", providerAuth)
                        .header("Accept-Language", "ar"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("سداد")));

        // Finance sees the frozen total, not the provider's whole balance.
        JsonNode report = json.readTree(mvc.perform(get("/admin/settlements/provider/{id}/payout-report", p.getId())
                        .header("Authorization", finance))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
        assertThat(report.get("total").decimalValue()).isEqualByComparingTo("50");
        assertThat(report.get("entryCount").asInt()).isEqualTo(2);
        assertThat(report.get("reportedAt").isNull()).isFalse();

        mvc.perform(post("/admin/settlements/provider/{id}/confirm-payout", p.getId())
                        .param("expectedAmount", "50").header("Authorization", finance))
                .andExpect(status().isOk());

        assertThat(statusOf(a)).isEqualTo(LedgerEntryStatus.SETTLED);
        assertThat(statusOf(b)).isEqualTo(LedgerEntryStatus.SETTLED);
        assertThat(statusOf(later)).isEqualTo(LedgerEntryStatus.DUE);
        assertThat(providerRepo.findById(p.getId()).orElseThrow().getSettlementReportedAt()).isNull();

        // With the first report confirmed, the provider can report the later entry.
        mvc.perform(patch("/provider/settlement/pay").header("Authorization", providerAuth))
                .andExpect(status().isOk());
    }

    @Test
    void confirmWithoutTheAmountOrWithADifferentAmountIsRefused() throws Exception {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = provider(owner);
        String finance = bearer(user(UserRole.ADMIN, AdminPermission.FINANCE));
        long a = entry(p, "30", LedgerEntryStatus.DUE);
        mvc.perform(patch("/provider/settlement/pay").header("Authorization", bearer(owner)))
                .andExpect(status().isOk());
        long later = entry(p, "45", LedgerEntryStatus.DUE);

        mvc.perform(post("/admin/settlements/provider/{id}/confirm-payout", p.getId())
                        .header("Authorization", finance))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("settlement.error.amount_required"));
        // 75 is the whole balance, but the provider only reported 30.
        mvc.perform(post("/admin/settlements/provider/{id}/confirm-payout", p.getId())
                        .param("expectedAmount", "75").header("Authorization", finance))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("settlement.error.amount_mismatch"));

        assertThat(statusOf(a)).isEqualTo(LedgerEntryStatus.DUE);
        assertThat(statusOf(later)).isEqualTo(LedgerEntryStatus.DUE);
        assertThat(providerRepo.findById(p.getId()).orElseThrow().getSettlementReportedAt()).isNotNull();
    }
}
