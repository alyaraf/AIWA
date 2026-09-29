package com.aiwa.controller;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AdminBookingSearchPatternTest {

    @Test
    void refsNamesAndWildcards() {
        assertThat(AdminController.searchPattern(null)).isEqualTo("%");
        assertThat(AdminController.searchPattern("  ")).isEqualTo("%");
        assertThat(AdminController.searchPattern("BK-2838")).isEqualTo("%2838%");
        assertThat(AdminController.searchPattern("Maadi Hammam")).isEqualTo("%maadi hammam%");
        assertThat(AdminController.searchPattern("50%_")).isEqualTo("%50%");
        assertThat(AdminController.searchPattern("%")).isEqualTo("%");
    }
}
