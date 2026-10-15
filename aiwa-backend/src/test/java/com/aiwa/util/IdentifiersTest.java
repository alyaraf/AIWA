package com.aiwa.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class IdentifiersTest {

    @Test
    void emailRegexAcceptsRealAddressesAndRejectsTheRest() {
        assertEquals("nour@mail.example.com", Identifiers.normalizeEmail(" Nour@Mail.Example.com "));
        assertThrows(IllegalArgumentException.class, () -> Identifiers.normalizeEmail("nour@example"));
        assertThrows(IllegalArgumentException.class, () -> Identifiers.normalizeEmail("nour@x..com"));
    }

    @Test
    @Timeout(2)
    void longDottedInputFailsFast() { // R7-19: the old pattern backtracked quadratically on this
        String evil = "a@" + ".".repeat(100_000) + "@";
        assertThrows(IllegalArgumentException.class, () -> Identifiers.normalizeEmail(evil));
    }
}
