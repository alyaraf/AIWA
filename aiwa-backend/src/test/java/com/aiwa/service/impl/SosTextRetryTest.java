package com.aiwa.service.impl;

import com.aiwa.dto.request.SafetyEventRequest;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.repository.*;
import com.aiwa.service.SmsService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * CR-08: an SOS text that was not delivered is re-sent by the sweep until the
 * SOS is closed, on its own threads, and a failed on-call text is counted for
 * the Prometheus alert. The scheduler itself is off in tests; these call the
 * sweep it runs.
 */
@SpringBootTest(properties = "aiwa.safety.oncall-phones=" + SosTextRetryTest.ON_CALL)
@ActiveProfiles("test")
class SosTextRetryTest {

    static final String ON_CALL = "+201177700000";
    private static final AtomicInteger SEQ = new AtomicInteger(0);

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    @Autowired SafetyService safety;
    @Autowired SafetyEventRepository safetyRepo;
    @Autowired SosDeliveryRepository deliveryRepo;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired MeterRegistry meterRegistry;
    @MockBean SmsService smsService;

    // ── fixtures ─────────────────────────────────────────────────────────────

    private static String phone() {
        return "+2011" + String.format("%08d", SEQ.incrementAndGet());
    }

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder()
                .fullName("sos " + role.name().toLowerCase() + " " + n)
                .email("sos" + n + "@test.aiwa").phone(phone()).password("x")
                .role(role).active(true).termsAccepted(true)
                .adminPermissions(new java.util.HashSet<>(Set.of(perms)))
                .build());
    }

    private Booking liveBooking() {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        com.aiwa.entity.Service s = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(p).name("Haircut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        return bookingRepo.save(Booking.builder()
                .customer(user(UserRole.CUSTOMER)).provider(p).service(s)
                .bookingDate(LocalDate.now()).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(11, 0))
                .totalPrice(new BigDecimal("300")).status(BookingStatus.ACCEPTED).build());
    }

    /** An SOS as the database holds it after a restart: the event, and nothing in memory. */
    private SafetyEvent storedSos(boolean resolved) {
        Booking b = liveBooking();
        return safetyRepo.save(SafetyEvent.builder().booking(b).actor(b.getCustomer())
                .type(SafetyEventType.SOS).resolved(resolved).build());
    }

    private SosDelivery row(SafetyEvent e, String kind, String to, SosDeliveryStatus status, LocalDateTime nextAttemptAt) {
        SosDelivery d = SosDelivery.builder().event(e).recipientKind(kind).phone(to).status(status).build();
        d.setNextAttemptAt(nextAttemptAt);
        return deliveryRepo.save(d);
    }

    private SosDelivery reload(SosDelivery d) {
        return deliveryRepo.findById(d.getId()).orElseThrow();
    }

    private SafetyEventRequest sos() {
        SafetyEventRequest r = new SafetyEventRequest();
        r.setType(SafetyEventType.SOS);
        return r;
    }

    // ── C1: the sweep ────────────────────────────────────────────────────────

    @Test
    void aPendingRowLeftByARestartIsSentByTheSweep() {
        SafetyEvent e = storedSos(false);
        SosDelivery lost = row(e, "ONCALL", phone(), SosDeliveryStatus.PENDING, null);
        SosDelivery inFlight = row(e, "CONTACT", phone(), SosDeliveryStatus.PENDING, LocalDateTime.now().plusMinutes(2));

        safety.retryDueSosTexts();

        verify(smsService, timeout(5000)).send(eq(lost.getPhone()), contains("AIWA SOS: booking #" + e.getBooking().getId()));
        await().atMost(Duration.ofSeconds(5)).untilAsserted(() ->
                assertThat(reload(lost).getStatus()).isEqualTo(SosDeliveryStatus.SENT));
        // A text another thread is still sending is left alone.
        verify(smsService, after(300).never()).send(eq(inFlight.getPhone()), anyString());
    }

    @Test
    void aFailedRowIsRetriedAfterItsBackOffAndNotBefore() {
        SafetyEvent e = storedSos(false);
        SosDelivery failed = row(e, "CONTACT", phone(), SosDeliveryStatus.FAILED, LocalDateTime.now().plusHours(1));

        safety.retryDueSosTexts();
        verify(smsService, after(700).never()).send(eq(failed.getPhone()), anyString());

        SosDelivery due = reload(failed);
        due.setNextAttemptAt(LocalDateTime.now().minusSeconds(1));
        deliveryRepo.save(due);
        safety.retryDueSosTexts();

        verify(smsService, timeout(5000)).send(eq(failed.getPhone()), contains("triggered an SOS on AIWA"));
        await().atMost(Duration.ofSeconds(5)).untilAsserted(() ->
                assertThat(reload(failed).getStatus()).isEqualTo(SosDeliveryStatus.SENT));
    }

    @Test
    void rowsOfAResolvedSosAreNotRetried() {
        SafetyEvent closed = storedSos(true);
        SosDelivery failed = row(closed, "ONCALL", phone(), SosDeliveryStatus.FAILED, null);
        SosDelivery pending = row(closed, "CONTACT", phone(), SosDeliveryStatus.PENDING, null);
        // Proves the sweep ran: an open SOS next to it is retried.
        SosDelivery open = row(storedSos(false), "ONCALL", phone(), SosDeliveryStatus.FAILED, null);

        safety.retryDueSosTexts();

        verify(smsService, timeout(5000)).send(eq(open.getPhone()), anyString());
        verify(smsService, after(500).never()).send(eq(failed.getPhone()), anyString());
        verify(smsService, never()).send(eq(pending.getPhone()), anyString());
        assertThat(reload(failed).getStatus()).isEqualTo(SosDeliveryStatus.FAILED);
    }

    // ── C2: the executor ─────────────────────────────────────────────────────

    @Test
    void sosTextsRunOnTheirOwnExecutorNotThePushPool() {
        AtomicReference<String> thread = new AtomicReference<>();
        doAnswer(inv -> {
            thread.set(Thread.currentThread().getName());
            return null;
        }).when(smsService).send(eq(ON_CALL), anyString());
        Booking b = liveBooking();

        safety.record(b.getId(), b.getCustomer().getId(), sos());

        await().atMost(Duration.ofSeconds(5)).untilAsserted(() -> assertThat(thread.get()).isNotNull());
        assertThat(thread.get()).startsWith("sos-");
    }

    // ── C3: the metric and the alert rule ────────────────────────────────────

    @Test
    void aFailedOnCallTextIsCountedAndScheduledForRetry() {
        doThrow(new RuntimeException("gateway down")).when(smsService).send(eq(ON_CALL), anyString());
        double before = meterRegistry.counter("aiwa.sos.oncall.text.failed").count();
        Booking b = liveBooking();

        Long eventId = safety.record(b.getId(), b.getCustomer().getId(), sos()).getId();

        // Three quick tries (2 s + 4 s apart), then FAILED.
        await().atMost(Duration.ofSeconds(20)).untilAsserted(() ->
                assertThat(deliveryRepo.findByEventIdOrderByIdAsc(eventId))
                        .singleElement().extracting(SosDelivery::getStatus).isEqualTo(SosDeliveryStatus.FAILED));
        assertThat(meterRegistry.counter("aiwa.sos.oncall.text.failed").count()).isEqualTo(before + 1);

        // Not again before the back-off: a sweep right now sends nothing more.
        SosDelivery d = deliveryRepo.findByEventIdOrderByIdAsc(eventId).get(0);
        assertThat(d.getNextAttemptAt()).isAfter(LocalDateTime.now());
        safety.retryDueSosTexts();
        verify(smsService, after(500).times(3)).send(eq(ON_CALL), anyString());
    }

    @Test
    @SuppressWarnings("unchecked")
    void theAlertRulesFileHasARuleOnTheFailedOnCallMetric() throws Exception {
        Path file = Path.of("..", "deploy", "monitoring", "alerts.yml");
        Map<String, Object> yaml = new org.yaml.snakeyaml.Yaml().load(Files.readString(file));
        List<Map<String, Object>> rules = ((List<Map<String, Object>>) yaml.get("groups")).stream()
                .flatMap(g -> ((List<Map<String, Object>>) g.get("rules")).stream()).toList();
        assertThat(rules).anySatisfy(r -> {
            assertThat((String) r.get("expr")).contains("aiwa_sos_oncall_text_failed_total");
            assertThat(r.get("alert")).isNotNull();
        });
    }

    // ── supportAlerted says only what happened ───────────────────────────────

    @Test
    void supportAlertedIsTrueOnlyOnceAnOnCallTextWasSent() {
        user(UserRole.ADMIN, AdminPermission.SUPPORT);   // an admin account existing is not an alert
        SafetyEvent e = storedSos(false);
        Long bookingId = e.getBooking().getId(), customerId = e.getActor().getId();
        SosDelivery d = row(e, "ONCALL", phone(), SosDeliveryStatus.PENDING, LocalDateTime.now().plusMinutes(2));

        assertThat(safety.events(bookingId, customerId).get(0).isSupportAlerted()).isFalse();

        d.setStatus(SosDeliveryStatus.SENT);
        deliveryRepo.save(d);
        assertThat(safety.events(bookingId, customerId).get(0).isSupportAlerted()).isTrue();
    }
}
