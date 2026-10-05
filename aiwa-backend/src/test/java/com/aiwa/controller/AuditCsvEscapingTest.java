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

    @Test
    void aFormulaHiddenBehindWhitespaceOrControlCharactersIsNeutralisedToo() {
        assertThat(AuditController.cell("  =1+1")).isEqualTo("'  =1+1");
        assertThat(AuditController.cell("\u0001@x")).isEqualTo("'\u0001@x");
        assertThat(AuditController.cell("\u00a0-2")).isEqualTo("'\u00a0-2");
        assertThat(AuditController.cell("a=b")).isEqualTo("a=b");
        assertThat(AuditController.cell("  fine")).isEqualTo("  fine");
    }
}
