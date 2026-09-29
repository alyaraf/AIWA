package com.aiwa.security;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class AiwaUserDetailsTest {

    @Test
    void tokensIssuedBeforeTheCutOffAreRejectedAtSecondPrecision() {
        AiwaUserDetails ud = new AiwaUserDetails("u", "p", true, List.of(),
                Instant.parse("2026-09-29T10:00:00.750Z"));
        assertThat(ud.acceptsTokenIssuedAt(Instant.parse("2026-09-29T09:59:59Z"))).isFalse();
        // A token minted in the same second as the cut-off (the login right after a reset) is fine.
        assertThat(ud.acceptsTokenIssuedAt(Instant.parse("2026-09-29T10:00:00Z"))).isTrue();
        assertThat(ud.acceptsTokenIssuedAt(null)).isFalse();
    }

    @Test
    void noCutOffAcceptsEverything() {
        AiwaUserDetails ud = new AiwaUserDetails("u", "p", true, List.of(), null);
        assertThat(ud.acceptsTokenIssuedAt(Instant.EPOCH)).isTrue();
    }
}
