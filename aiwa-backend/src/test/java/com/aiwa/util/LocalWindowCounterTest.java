package com.aiwa.util;

import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

class LocalWindowCounterTest {

    @Test
    void countsPerKeyWithinTheWindow() {
        LocalWindowCounter counter = new LocalWindowCounter();
        assertThat(counter.increment("a", Duration.ofMinutes(1))).isEqualTo(1);
        assertThat(counter.increment("a", Duration.ofMinutes(1))).isEqualTo(2);
        assertThat(counter.increment("b", Duration.ofMinutes(1))).isEqualTo(1);
    }

    @Test
    void startsANewWindowOnceTheOldOneExpired() throws Exception {
        LocalWindowCounter counter = new LocalWindowCounter();
        counter.increment("a", Duration.ofMillis(20));
        counter.increment("a", Duration.ofMillis(20));
        Thread.sleep(40);
        assertThat(counter.increment("a", Duration.ofMillis(20))).isEqualTo(1);
    }
}
