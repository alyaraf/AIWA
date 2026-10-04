package com.aiwa.util;

import org.junit.jupiter.api.Test;

import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** AU-08 / M-3: TOTP secrets encrypted at rest, with plain values still readable. */
class TotpSecretConverterTest {

    private static final String KEY = Base64.getEncoder().encodeToString(new byte[32]);
    private static final String SECRET = "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP";

    @Test
    void withAKeyTheSecretIsStoredEncryptedAndReadBack() {
        TotpSecretConverter c = new TotpSecretConverter(KEY);
        String stored = c.convertToDatabaseColumn(SECRET);
        assertThat(stored).startsWith(TotpSecretConverter.PREFIX).doesNotContain(SECRET);
        assertThat(stored.length()).isLessThan(255);
        assertThat(c.convertToEntityAttribute(stored)).isEqualTo(SECRET);
        assertThat(c.convertToDatabaseColumn(SECRET)).as("random IV").isNotEqualTo(stored);
    }

    @Test
    void aSecretStoredBeforeTheKeyIsStillRead() {
        assertThat(new TotpSecretConverter(KEY).convertToEntityAttribute(SECRET)).isEqualTo(SECRET);
    }

    @Test
    void withoutAKeyNothingChanges() {
        TotpSecretConverter c = new TotpSecretConverter(null);
        assertThat(c.convertToDatabaseColumn(SECRET)).isEqualTo(SECRET);
        assertThat(c.convertToEntityAttribute(null)).isNull();
    }

    @Test
    void aWrongKeyOrSizeFailsLoudly() {
        String stored = new TotpSecretConverter(KEY).convertToDatabaseColumn(SECRET);
        String other = Base64.getEncoder().encodeToString(new byte[32]).replace('A', 'B');
        assertThatThrownBy(() -> new TotpSecretConverter(other).convertToEntityAttribute(stored))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new TotpSecretConverter(Base64.getEncoder().encodeToString(new byte[16])))
                .isInstanceOf(IllegalStateException.class);
    }
}
