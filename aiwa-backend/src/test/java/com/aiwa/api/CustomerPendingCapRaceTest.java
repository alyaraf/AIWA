package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.Availability;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.util.AiwaTime;
import com.fasterxml.jackson.databind.ObjectMapper;
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

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** SA-10: parallel requests to different providers cannot get past the per-customer open-request cap. */
@SpringBootTest(properties = "aiwa.booking.max-open-requests-per-customer=1")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CustomerPendingCapRaceTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    private User user(UserRole role, String tag) {
        return userRepo.save(User.builder().fullName(tag).email(tag + "@test.aiwa")
                .phone(TestPhones.next())
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true).build());
    }

    private com.aiwa.entity.Service provider(String tag) {
        User owner = user(UserRole.PROVIDER, tag);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Studio " + tag)
                .address("12 Nile St").latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(p).dayOfWeek(d).startTime(LocalTime.of(8, 0))
                    .endTime(LocalTime.of(22, 0)).slotDurationMinutes(30).available(true).build());
        }
        return serviceRepo.save(com.aiwa.entity.Service.builder().provider(p).name("Cut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("100")).durationMinutes(60).active(true).build());
    }

    @Test
    void twoParallelRequestsForTwoProvidersLeaveOnlyOnePending() throws Exception {
        ((InMemoryRedisRuntimeService) redis).clear();
        var s1 = provider("race-p1");
        var s2 = provider("race-p2");
        User customer = user(UserRole.CUSTOMER, "race-customer");
        String token = "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", customer.getEmail(), "password", PASSWORD))))
                .andReturn().getResponse().getContentAsString()).get("data").get("accessToken").asText();

        CountDownLatch go = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(2);
        List<Future<Integer>> results = new ArrayList<>();
        for (var s : List.of(s1, s2)) {
            results.add(pool.submit(() -> {
                go.await();
                return mvc.perform(post("/bookings").header("Authorization", token)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json.writeValueAsString(Map.of("providerId", s.getProvider().getId(),
                                        "serviceId", s.getId(), "bookingType", "SCHEDULED",
                                        "bookingDate", AiwaTime.today().plusDays(3).toString(),
                                        "startTime", "10:00", "homeService", false))))
                        .andReturn().getResponse().getStatus();
            }));
        }
        go.countDown();
        for (var f : results) f.get();
        pool.shutdown();

        assertThat(bookingRepo.countByCustomerIdAndStatus(customer.getId(), BookingStatus.PENDING)).isEqualTo(1);
    }
}
