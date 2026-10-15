package com.aiwa.api;

import com.aiwa.support.TestPhones;
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
                .phone(TestPhones.next())
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

    // ── R4-02: SOS / support projections use the agreed destination ──────────────────────────────────────

    @Autowired com.aiwa.repository.BookingRepository bookingRepo;

    private String support() throws Exception {
        int n = SEQ.incrementAndGet();
        User u = userRepo.save(User.builder().fullName("sos support " + n).email("sos-support" + n + "@test.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD)).role(UserRole.ADMIN)
                .active(true).termsAccepted(true)
                .adminPermissions(new java.util.HashSet<>(java.util.Set.of(com.aiwa.enums.AdminPermission.SUPPORT))).build());
        return login(u);
    }

    private long sos(long bookingId) throws Exception {
        mvc.perform(patch("/bookings/" + bookingId + "/accept").header("Authorization", provider)).andExpect(status().isOk());
        return data(mvc.perform(post("/bookings/" + bookingId + "/safety").header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "type", "SOS", "latitude", 30.5, "longitude", 31.5))))
                .andExpect(status().isCreated())).get("id").asLong();
    }

    private JsonNode adminEvent(String support, long eventId) throws Exception {
        for (JsonNode e : data(mvc.perform(get("/admin/safety?status=ALL").header("Authorization", support))
                .andExpect(status().isOk())).get("content")) {
            if (e.get("id").asLong() == eventId) return e;
        }
        throw new AssertionError("SOS " + eventId + " not in the queue");
    }

    @Test
    void sosQueueShowsTheAgreedDestinationNotTheEditedSavedAddress() throws Exception {
        long addr = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long id = homeBooking(addr);
        long event = sos(id);

        mvc.perform(put("/account/addresses/" + addr).header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "label", "Far away", "addressLine", "99 Desert Rd", "latitude", 35.0, "longitude", 35.0))))
                .andExpect(status().isOk());

        JsonNode e = adminEvent(support(), event);
        assertThat(e.get("address").asText()).isEqualTo("1 Nile St");
        assertThat(e.get("destinationLatitude").asDouble()).isEqualTo(30.07);
        assertThat(e.get("destinationLongitude").asDouble()).isEqualTo(31.23);
        // the reported fix is a different thing and stays as the device sent it
        assertThat(e.get("latitude").asDouble()).isEqualTo(30.5);
        assertThat(e.get("longitude").asDouble()).isEqualTo(31.5);
        assertThat(e.get("destinationBackfilled").asBoolean()).isFalse();
    }

    @Test
    void sosFollowsAnExplicitDestinationAmendmentAndTheResolvedProjectionToo() throws Exception {
        long near = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long other = address(customer, "Office", "5 Tahrir Sq", 30.05, 31.24);
        long id = homeBooking(near);
        long event = sos(id);
        data(amend(customer, id, other).andExpect(status().isOk()));

        String support = support();
        assertThat(adminEvent(support, event).get("address").asText()).isEqualTo("5 Tahrir Sq");
        mvc.perform(put("/account/addresses/" + other).header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "label", "Office", "addressLine", "Edited later", "latitude", 30.05, "longitude", 31.24))))
                .andExpect(status().isOk());
        JsonNode closed = data(mvc.perform(post("/admin/safety/" + event + "/resolve").header("Authorization", support)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("notes", "called her"))))
                .andExpect(status().isOk()));
        assertThat(closed.get("address").asText()).as("resolve returns the same projection").isEqualTo("5 Tahrir Sq");
    }

    @Test
    void aBackfilledHistoricalBookingStillShowsItsSnapshotAndSaysItWasReconstructed() throws Exception {
        long addr = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long id = homeBooking(addr);
        long event = sos(id);
        com.aiwa.entity.Booking b = bookingRepo.findById(id).orElseThrow();
        b.setDestinationBackfilled(true); // what migration V34 sets on a row it copied from the saved address
        bookingRepo.save(b);
        mvc.perform(put("/account/addresses/" + addr).header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "label", "Home", "addressLine", "Moved", "latitude", 30.07, "longitude", 31.23))))
                .andExpect(status().isOk());
        JsonNode e = adminEvent(support(), event);
        assertThat(e.get("address").asText()).isEqualTo("1 Nile St");
        assertThat(e.get("destinationBackfilled").asBoolean()).isTrue();
    }

    @Test
    void aLegacyRowWithNoSnapshotFallsBackToTheSavedAddress() throws Exception {
        long addr = address(customer, "Home", "1 Nile St", 30.07, 31.23);
        long id = homeBooking(addr);
        long event = sos(id);
        com.aiwa.entity.Booking b = bookingRepo.findById(id).orElseThrow();
        b.setDestinationAddress(null); // a row written by a release that did not record the snapshot
        bookingRepo.save(b);
        assertThat(adminEvent(support(), event).get("address").asText()).isEqualTo("1 Nile St");
    }
}
