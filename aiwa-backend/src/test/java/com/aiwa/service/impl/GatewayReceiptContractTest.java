package com.aiwa.service.impl;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration contract (R4 follow-up to P-07): with a receipt path configured, a 2xx that does not carry the provider's
 * receipt is not "accepted"; without one the lenient behaviour is unchanged.
 */
class GatewayReceiptContractTest {

    @Test
    void withoutAReceiptPathTheLenientBehaviourIsUnchanged() {
        assertThat(GatewayRefusal.of("{\"queued\":true}", "")).isNull();
        assertThat(GatewayRefusal.of("OK", null)).isNull();
        assertThat(GatewayRefusal.of("", "  ")).isNull();
        assertThat(GatewayRefusal.of("{\"success\":false}", null)).contains("success=false");
    }

    @Test
    void aConfiguredReceiptMustBePresentAndNotBlank() {
        assertThat(GatewayRefusal.of("{\"data\":{\"messageId\":\"m-123\"}}", "data.messageId")).isNull();
        assertThat(GatewayRefusal.of("{\"id\":42}", "id")).isNull();
        assertThat(GatewayRefusal.of("{\"data\":{}}", "data.messageId")).contains("no receipt");
        assertThat(GatewayRefusal.of("{\"data\":{\"messageId\":\"\"}}", "data.messageId")).contains("no receipt");
        assertThat(GatewayRefusal.of("{\"data\":{\"messageId\":null}}", "data.messageId")).contains("no receipt");
        assertThat(GatewayRefusal.of("{\"queued\":true}", "data.messageId")).contains("no receipt");
    }

    @Test
    void anUnreadableOrEmptyBodyIsNotAReceiptWhenOneIsRequired() {
        assertThat(GatewayRefusal.of("", "id")).contains("empty body");
        assertThat(GatewayRefusal.of(null, "id")).contains("empty body");
        assertThat(GatewayRefusal.of("<html>proxy</html>", "id")).contains("not JSON");
    }

    @Test
    void anExplicitRefusalStillWinsOverAReceipt() {
        assertThat(GatewayRefusal.of("{\"success\":false,\"id\":\"x\"}", "id")).contains("success=false");
    }
}
