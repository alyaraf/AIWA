package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.sun.net.httpserver.HttpServer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * C-1 (audit 2026-10-03): the real gateway adapter, against a stub HTTP server.
 * A failed text must throw, so the SOS delivery tracker records FAILED, retries
 * it and counts the on-call failure, instead of recording SENT.
 */
class ExternalSmsServiceTest {

    private HttpServer server;
    private final AtomicReference<Integer> status = new AtomicReference<>(200);
    private final AtomicReference<String> body = new AtomicReference<>("");
    private final AtomicReference<String> received = new AtomicReference<>();
    private ExternalSmsService sms;
    private SimpleMeterRegistry meters;

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/sms", exchange -> {
            received.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8)
                    + " auth=" + exchange.getRequestHeaders().getFirst("Authorization"));
            byte[] out = body.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(status.get(), out.length == 0 ? -1 : out.length);
            if (out.length > 0) try (OutputStream os = exchange.getResponseBody()) { os.write(out); }
            exchange.close();
        });
        server.start();
        sms = new ExternalSmsService(new RestTemplateBuilder());
        ReflectionTestUtils.setField(sms, "apiUrl", "http://127.0.0.1:" + server.getAddress().getPort() + "/sms");
        ReflectionTestUtils.setField(sms, "apiKey", "test-key");
        ReflectionTestUtils.setField(sms, "sender", "AIWA");
        meters = new SimpleMeterRegistry();
        sms.setMeterRegistry(meters);
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private double count(String result) {
        var c = meters.find(ExternalSmsService.SENT_METRIC).tag("result", result).counter();
        return c == null ? 0 : c.count();
    }

    @Test
    void aDeliveredTextReturnsAndPostsTheContract() {
        body.set("{\"success\":true,\"id\":\"abc\"}");
        assertThatCode(() -> sms.send("+201000000001", "hello")).doesNotThrowAnyException();
        assertThat(received.get()).contains("\"to\":\"+201000000001\"").contains("\"message\":\"hello\"")
                .contains("auth=Bearer test-key");
        assertThat(count("ok")).isEqualTo(1);
    }

    @Test
    void anEmptyOrNonJson2xxBodyCountsAsSent() {
        body.set("");
        assertThatCode(() -> sms.send("+201000000001", "x")).doesNotThrowAnyException();
        body.set("OK 12345");
        assertThatCode(() -> sms.send("+201000000001", "x")).doesNotThrowAnyException();
    }

    @Test
    void aServerErrorThrows() {
        status.set(500);
        body.set("{\"error\":\"boom\"}");
        assertThatThrownBy(() -> sms.send("+201000000001", "help")).isInstanceOf(BusinessException.class);
        assertThat(count("error")).isEqualTo(1);
    }

    @Test
    void a200WithAnErrorBodyThrows() {
        for (String refused : new String[]{
                "{\"success\":false,\"message\":\"insufficient credit\"}",
                "{\"ok\":false}",
                "{\"status\":\"FAILED\"}",
                "{\"error\":{\"code\":21211,\"message\":\"invalid number\"}}",
                "{\"error\":\"invalid sender\"}"}) {
            body.set(refused);
            assertThatThrownBy(() -> sms.send("+201000000001", "help"))
                    .as(refused).isInstanceOf(BusinessException.class);
        }
        assertThat(count("refused")).isEqualTo(5);
    }

    @Test
    void benignErrorFieldsDoNotCountAsRefusals() {
        for (String fine : new String[]{"{\"error\":null}", "{\"error\":\"\"}", "{\"error\":false}",
                "{\"status\":\"queued\"}", "[1,2]"}) {
            body.set(fine);
            assertThatCode(() -> sms.send("+201000000001", "x")).as(fine).doesNotThrowAnyException();
        }
    }

    @Test
    void anUnreachableGatewayThrows() {
        server.stop(0);
        assertThatThrownBy(() -> sms.send("+201000000001", "help")).isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> sms.sendOtp("+201000000001", "123456", 5)).isInstanceOf(BusinessException.class);
    }

    @Test
    void aMissingConfigurationThrows() {
        ReflectionTestUtils.setField(sms, "apiKey", "");
        assertThatThrownBy(() -> sms.send("+201000000001", "help")).isInstanceOf(BusinessException.class);
    }
}
