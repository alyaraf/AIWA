package com.aiwa.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * OPS-5: Prometheus can scrape /actuator/prometheus with the shared token, and
 * nobody else can tell the endpoint exists.
 */
@SpringBootTest(properties = "aiwa.metrics.token=test-scrape-token")
@AutoConfigureMockMvc
@AutoConfigureObservability
@ActiveProfiles("test")
class MetricsEndpointTest {

    @Autowired MockMvc mvc;

    @Test
    void withoutTheTokenTheEndpointLooksMissing() throws Exception {
        mvc.perform(get("/actuator/prometheus")).andExpect(status().isNotFound());
        mvc.perform(get("/actuator/prometheus").header("Authorization", "Bearer wrong"))
                .andExpect(status().isNotFound());
    }

    @Test
    void anEncodedPathDoesNotSkipTheToken() throws Exception {
        // L-24: the filter compared the raw URI; MVC routes on the decoded one.
        mvc.perform(get(new java.net.URI("/actuator/promethe%75s"))).andExpect(status().isNotFound());
    }

    @Test
    void theScraperGetsPrometheusText() throws Exception {
        mvc.perform(get("/actuator/prometheus").header("Authorization", "Bearer test-scrape-token"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("jvm_memory_used_bytes")))
                .andExpect(content().string(containsString("http_server_requests")));
    }

    @Test
    void theOtherActuatorEndpointsStayClosed() throws Exception {
        mvc.perform(get("/actuator/env")).andExpect(status().isUnauthorized());
        // Health stays public (503 here only because no Redis runs in this test).
        mvc.perform(get("/actuator/health")).andExpect(result ->
                org.assertj.core.api.Assertions.assertThat(result.getResponse().getStatus()).isIn(200, 503));
    }
}
