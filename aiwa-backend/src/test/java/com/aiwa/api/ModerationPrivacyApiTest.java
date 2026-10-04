package com.aiwa.api;

import com.aiwa.entity.Complaint;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.ComplaintRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * M-2: an admin flag is filed by the admin and never shows in the flagged user's
 * "My reports" (older flags stored with the user as reporter are hidden too).
 * L-26: a suspended provider's gallery is not public.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ModerationPrivacyApiTest {

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
    @Autowired ComplaintRepository complaintRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void resetLimits() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("modpriv-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010773" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new HashSet<>() : new HashSet<>(EnumSet.copyOf(List.of(perms))))
                .build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("data").get("accessToken").asText();
    }

    @Test
    void anAdminFlagNeverShowsInTheFlaggedUsersOwnReports() throws Exception {
        User target = user(UserRole.CUSTOMER);
        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        mvc.perform(post("/admin/users/" + target.getId() + "/flag").header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"internal: suspected fraud\"}"))
                .andExpect(status().isOk());
        // A flag stored the old way, with the flagged user as its reporter.
        complaintRepo.save(Complaint.builder().reporter(target).targetUser(target).category("ADMIN_FLAG")
                .description("legacy internal note").status(ComplaintStatus.ESCALATED).flagged(true).build());

        mvc.perform(get("/complaints/my").header("Authorization", login(target)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content", hasSize(0)));
    }

    @Test
    void identityDocumentsAndPrivateChatsNeedTheRightPermission() throws Exception {
        // M-3: an admin with no permission used to read both.
        String none = login(user(UserRole.ADMIN));
        String finance = login(user(UserRole.ADMIN, AdminPermission.FINANCE));
        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));

        mvc.perform(get("/admin/verification/1/documents/selfie").header("Authorization", none))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("auth.error.forbidden_role"));
        mvc.perform(get("/admin/verification/1/documents/selfie").header("Authorization", finance))
                .andExpect(status().isForbidden());

        mvc.perform(get("/admin/bookings/999999/chat").header("Authorization", none))
                .andExpect(status().isForbidden());
        mvc.perform(get("/admin/bookings/999999/chat").header("Authorization", finance))
                .andExpect(status().isOk()); // dispute evidence
        mvc.perform(get("/admin/bookings/999999/chat").header("Authorization", support))
                .andExpect(status().isOk());
    }

    @Test
    void aSuspendedProvidersGalleryIsNotPublic() throws Exception {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        mvc.perform(get("/provider/gallery/" + p.getId())).andExpect(status().isOk());

        p.setVerificationStatus(VerificationStatus.SUSPENDED);
        providerRepo.save(p);
        mvc.perform(get("/provider/gallery/" + p.getId())).andExpect(status().isNotFound());
        mvc.perform(get("/provider/gallery/" + p.getId()).header("Authorization", login(owner)))
                .andExpect(status().isOk());
    }
}
