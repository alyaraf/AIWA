package com.aiwa.api;

import com.aiwa.entity.Availability;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.util.AiwaTime;
import com.fasterxml.jackson.databind.JsonNode;
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
import org.springframework.test.web.servlet.ResultActions;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** B-05: the booking owns its destination; editing the saved address changes nothing, an explicit amendment does. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BookingDestinationSnapshotApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    private String customer, provider;
    private ProviderProfile profile;
    private com.aiwa.entity.Service service;

    private User user(UserRole role) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("dest-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010663" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true).build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + data(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk())).get("accessToken").asText();
    }

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    @BeforeEach
    void setUp() throws Exception {
        ((InMemoryRedisRuntimeService) redis).clear();
        User owner = user(UserRole.PROVIDER);
        profile = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Studio " + owner.getId())
                .address("Zamalek, Cairo").latitude(30.06).longitude(31.22).serviceRadiusKm(10.0)
                .primaryCategory(ServiceCategory.HAIR).verificationStatus(VerificationStatus.APPROVED)
                .travelBufferMinutes(0).build());
        service = serviceRepo.save(com.aiwa.entity.Service.builder().provider(profile).name("Haircut")
                .category(ServiceCategory.HAIR).price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(profile).dayOfWeek(d).startTime(LocalTime.MIN)
                    .endTime(LocalTime.of(23, 59)).slotDurationMinutes(30).available(true).build());
        }
        customer = login(user(UserRole.CUSTOMER));
        provider = login(owner);
    }

    private long address(String token, String label, String line, double lat, double lng) throws Exception {
        return data(mvc.perform(post("/account/addresses").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "label", label, "addressLine", line, "latitude", lat, "longitude", lng)))
        ).andExpect(status().isCreated())).get("id").asLong();
    }

    private long homeBooking(long addressId) throws Exception {
        Map<String, Object> body = new HashMap<>(Map.of("providerId", profile.getId(), "serviceId", service.getId(),
                "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(3).toString(),
                "startTime", "10:00", "homeService", true, "savedAddressId", addressId));
        return data(mvc.perform(post("/bookings").header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().isCreated())).get("id").asLong();
    }

    private JsonNode bookingAs(String token, long id) throws Exception {
        return data(mvc.perform(get("/bookings/" + id).header("Authorization", token)).andExpect(status().isOk()));
    }

    private ResultActions amend(String token, long id, long addressId) throws Exception {
        return mvc.perform(patch("/bookings/" + id + "/destination").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("savedAddressId", addressId))));
    }

    @Test
    void editingTheSavedAddressDoesNotMoveAnExistingBooking() throws Exception {
        long addr = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long id = homeBooking(addr);

        mvc.perform(put("/account/addresses/" + addr).header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "label", "Far away", "addressLine", "99 Desert Rd", "latitude", 35.0, "longitude", 35.0))))
                .andExpect(status().isOk());

        for (String who : new String[]{customer, provider}) {
            JsonNode dest = bookingAs(who, id).get("savedAddress");
            assertThat(dest.get("addressLine").asText()).isEqualTo("1 Nile St");
            assertThat(dest.get("latitude").asDouble()).isEqualTo(30.07);
            assertThat(dest.get("label").asText()).isEqualTo("Home");
        }
    }

    @Test
    void anAmendmentIsRadiusCheckedResetsAnAcceptedVisitAndTellsTheProvider() throws Exception {
        long near = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long other = address(customer, "Office", "5 Tahrir Sq", 30.05, 31.24);
        long far = address(customer, "Alexandria", "Corniche", 31.2, 29.9);
        long id = homeBooking(near);
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", provider)).andExpect(status().isOk());

        amend(customer, id, far).andExpect(status().isBadRequest()); // outside the 10 km radius
        assertThat(bookingAs(customer, id).get("savedAddress").get("addressLine").asText()).isEqualTo("1 Nile St");

        JsonNode amended = data(amend(customer, id, other).andExpect(status().isOk()));
        assertThat(amended.get("savedAddress").get("addressLine").asText()).isEqualTo("5 Tahrir Sq");
        assertThat(amended.get("status").asText()).as("provider must confirm the new place").isEqualTo("PENDING");
        assertThat(amended.get("destinationAmendedAt").asText()).isNotBlank();
    }

    @Test
    void onlyTheCustomerOwningBothTheBookingAndTheAddressMayAmend() throws Exception {
        long near = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long id = homeBooking(near);
        amend(provider, id, near).andExpect(status().isBadRequest());

        String stranger = login(user(UserRole.CUSTOMER));
        amend(stranger, id, near).andExpect(status().isBadRequest());
        long theirs = address(stranger, "X", "Other", 30.07, 31.23);
        amend(customer, id, theirs).andExpect(status().isBadRequest()); // a saved address of another account
    }
}
