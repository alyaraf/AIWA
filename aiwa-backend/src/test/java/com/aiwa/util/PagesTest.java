package com.aiwa.util;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** BE-40: request paging can't go negative or load a whole table. */
class PagesTest {

    @Test
    void appListsAreCappedAt100AndNeverNegative() {
        assertThat(Pages.of(-1, 1_000_000).getPageNumber()).isZero();
        assertThat(Pages.of(-1, 1_000_000).getPageSize()).isEqualTo(100);
        assertThat(Pages.of(2, 0).getPageSize()).isEqualTo(1);
        assertThat(Pages.of(3, 20).getPageNumber()).isEqualTo(3);
    }

    @Test
    void adminListsKeepThe500RowsThePanelAsksFor() {
        assertThat(Pages.admin(0, 500).getPageSize()).isEqualTo(500);
        assertThat(Pages.admin(0, 1_000_000).getPageSize()).isEqualTo(500);
    }
}
