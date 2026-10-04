package com.aiwa.util;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** AU-08 / M-3: ID documents encrypted at rest, and files written before the key existed still readable. */
class PrivateFileCipherTest {

    private static final String KEY = Base64.getEncoder().encodeToString(new byte[32]);
    private static final byte[] ID_PHOTO = "ÿØÿNATIONAL-ID-JPEG-BYTES".getBytes(StandardCharsets.ISO_8859_1);

    @Test
    void withAKeyTheBytesAreStoredEncryptedAndComeBackExactly() {
        PrivateFileCipher c = new PrivateFileCipher(KEY);
        byte[] stored = c.encrypt(ID_PHOTO);
        assertThat(new String(stored, StandardCharsets.ISO_8859_1)).startsWith(PrivateFileCipher.MAGIC)
                .doesNotContain("NATIONAL-ID");
        assertThat(c.decrypt(stored)).isEqualTo(ID_PHOTO);
        assertThat(c.encrypt(ID_PHOTO)).as("random IV").isNotEqualTo(stored);
    }

    @Test
    void aFileStoredBeforeTheKeyIsReadAsItIs() {
        assertThat(new PrivateFileCipher(KEY).decrypt(ID_PHOTO)).isEqualTo(ID_PHOTO);
    }

    @Test
    void withoutAKeyNothingChangesAndAnEncryptedFileFailsLoudly() {
        PrivateFileCipher none = new PrivateFileCipher(null);
        assertThat(none.enabled()).isFalse();
        assertThat(none.encrypt(ID_PHOTO)).isEqualTo(ID_PHOTO);
        byte[] stored = new PrivateFileCipher(KEY).encrypt(ID_PHOTO);
        assertThatThrownBy(() -> none.decrypt(stored)).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void aTamperedFileOrWrongKeyIsRefused() {
        byte[] stored = new PrivateFileCipher(KEY).encrypt(ID_PHOTO);
        stored[stored.length - 1] ^= 1;
        assertThatThrownBy(() -> new PrivateFileCipher(KEY).decrypt(stored)).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new PrivateFileCipher(Base64.getEncoder().encodeToString(new byte[16])))
                .isInstanceOf(IllegalStateException.class);
    }
}
