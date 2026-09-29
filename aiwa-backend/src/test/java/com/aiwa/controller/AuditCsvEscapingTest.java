package com.aiwa.controller;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AuditCsvEscapingTest {

    @Test
    void formulasAreNeutralisedAndSeparatorsQuoted() {
        assertThat(AuditController.cell("=HYPERLINK(\"http://x\")")).isEqualTo("\"'=HYPERLINK(\"\"http://x\"\")\"");
        assertThat(AuditController.cell("+1 (555)")).isEqualTo("'+1 (555)");
        assertThat(AuditController.cell("a,b")).isEqualTo("\"a,b\"");
        assertThat(AuditController.cell("plain")).isEqualTo("plain");
        assertThat(AuditController.cell(null)).isEmpty();
    }
}
