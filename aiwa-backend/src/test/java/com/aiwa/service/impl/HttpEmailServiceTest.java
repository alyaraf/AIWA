package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** P-07: HTTP 2xx alone is not proof the gateway accepted the message. */
class HttpEmailServiceTest {

    private HttpServer server;
    private final AtomicReference<Integer> status = new AtomicReference<>(200);
    private final AtomicReference<String> body = new AtomicReference<>("");
    private HttpEmailService email;

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/mail", exchange -> {
            exchange.getRequestBody().readAllBytes();
            byte[] out = body.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(status.get(), out.length == 0 ? -1 : out.length);
            if (out.length > 0) try (OutputStream os = exchange.getResponseBody()) { os.write(out); }
            exchange.close();
        });
        server.start();
        email = new HttpEmailService(new RestTemplateBuilder());
        ReflectionTestUtils.setField(email, "apiUrl", "http://127.0.0.1:" + server.getAddress().getPort() + "/mail");
        ReflectionTestUtils.setField(email, "apiKey", "k");
        ReflectionTestUtils.setField(email, "from", "no-reply@aiwa.test");
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    @Test
    void anAcceptedMessageIsFine() {
        body.set("{\"id\":\"abc\",\"status\":\"queued\"}");
        assertThatCode(() -> email.send("a@b.test", "s", "t")).doesNotThrowAnyException();
        body.set("");
        assertThatCode(() -> email.send("a@b.test", "s", "t")).doesNotThrowAnyException();
    }

    @Test
    void a200WithARefusalInTheBodyFails() {
        for (String refusal : new String[]{"{\"success\":false}", "{\"status\":\"rejected\"}",
                "{\"error\":{\"code\":\"invalid_to\"}}", "{\"ok\":false,\"message\":\"blocked\"}"}) {
            body.set(refusal);
            assertThatThrownBy(() -> email.send("a@b.test", "s", "t"))
                    .as(refusal).isInstanceOf(BusinessException.class);
        }
    }

    @Test
    void aGatewayErrorStatusFails() {
        status.set(503);
        assertThatThrownBy(() -> email.send("a@b.test", "s", "t")).isInstanceOf(BusinessException.class);
    }
}
