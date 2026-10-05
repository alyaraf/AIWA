package com.aiwa.util;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** I-06: gateway/driver messages are scrubbed before they reach the log. */
class LogSafeTest {

    @Test
    void contactsAndTokensAreRemoved() {
        String s = LogSafe.scrub("HTTP 400 for +20 100 123 4567 / jane.doe@example.com Authorization: Bearer abcdef1234567890 password=hunter2hunter2");
        assertThat(s).doesNotContain("jane.doe").doesNotContain("123 4567").doesNotContain("abcdef1234567890")
                .doesNotContain("hunter2hunter2");
        assertThat(s).contains("<email>").contains("<number>");
    }

    @Test
    void newlinesAreFlattenedAndLongTextIsTruncated() {
        assertThat(LogSafe.scrub("a\nb\r\nc")).doesNotContain("\n").doesNotContain("\r");
        assertThat(LogSafe.scrub("x".repeat(1000)).length()).isLessThan(310);
        assertThat(LogSafe.scrub(null)).isEmpty();
    }
}
