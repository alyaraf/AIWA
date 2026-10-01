package com.aiwa.security;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class AiwaUserDetailsTest {

    /** DR-018: compared to the millisecond (tokens carry their issue time in ms). */
    @Test
    void tokensIssuedBeforeTheCutOffAreRejectedToTheMillisecond() {
        AiwaUserDetails ud = new AiwaUserDetails("u", "p", true, List.of(),
                Instant.parse("2026-09-29T10:00:00.750Z"));
        assertThat(ud.acceptsTokenIssuedAt(Instant.parse("2026-09-29T09:59:59Z"))).isFalse();
        // Earlier in the same second as the cut-off: used to pass, now refused.
        assertThat(ud.acceptsTokenIssuedAt(Instant.parse("2026-09-29T10:00:00.200Z"))).isFalse();
        // The login right after the reset.
        assertThat(ud.acceptsTokenIssuedAt(Instant.parse("2026-09-29T10:00:00.751Z"))).isTrue();
        assertThat(ud.acceptsTokenIssuedAt(null)).isFalse();
    }

    @Test
    void noCutOffAcceptsEverything() {
        AiwaUserDetails ud = new AiwaUserDetails("u", "p", true, List.of(), null);
        assertThat(ud.acceptsTokenIssuedAt(Instant.EPOCH)).isTrue();
    }
}
