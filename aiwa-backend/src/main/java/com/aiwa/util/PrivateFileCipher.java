package com.aiwa.util;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;

/**
 * AU-08 / M-3: private files (ID documents and selfies) encrypted at rest with AES-256-GCM.
 * A copy of the upload volume or a backup alone no longer shows anyone's ID.
 *
 * <p>Key: {@code DOCUMENT_ENCRYPTION_KEY}, 32 bytes, base64. Without it files are written as
 * before. A file starts with {@value #MAGIC} when it is encrypted, so files stored before the
 * key existed are still read as they are, and an encrypted file without the key fails loudly
 * instead of serving noise.
 */
public class PrivateFileCipher {

    static final String MAGIC = "AIWAENC1";
    private static final byte[] MAGIC_BYTES = MAGIC.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final SecretKeySpec key;

    public PrivateFileCipher(String base64Key) {
        if (base64Key == null || base64Key.isBlank()) {
            key = null;
        } else {
            byte[] raw = Base64.getDecoder().decode(base64Key.trim());
            if (raw.length != 32) throw new IllegalStateException("DOCUMENT_ENCRYPTION_KEY must be 32 bytes, base64-encoded");
            key = new SecretKeySpec(raw, "AES");
        }
    }

    public boolean enabled() {
        return key != null;
    }

    /** The bytes to write: encrypted when a key is set, else unchanged. */
    public byte[] encrypt(byte[] plain) {
        if (key == null) return plain;
        try {
            byte[] iv = new byte[IV_BYTES];
            RANDOM.nextBytes(iv);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] ct = c.doFinal(plain);
            return ByteBuffer.allocate(MAGIC_BYTES.length + iv.length + ct.length)
                    .put(MAGIC_BYTES).put(iv).put(ct).array();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Could not encrypt a private file", e);
        }
    }

    /** The original bytes: decrypted when the file is encrypted, else returned as they are. */
    public byte[] decrypt(byte[] stored) {
        if (!isEncrypted(stored)) return stored;
        if (key == null) throw new IllegalStateException("A private file is encrypted but DOCUMENT_ENCRYPTION_KEY is not set");
        try {
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, stored, MAGIC_BYTES.length, IV_BYTES));
            int from = MAGIC_BYTES.length + IV_BYTES;
            return c.doFinal(stored, from, stored.length - from);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Could not decrypt a private file (wrong DOCUMENT_ENCRYPTION_KEY?)", e);
        }
    }

    static boolean isEncrypted(byte[] data) {
        return data.length > MAGIC_BYTES.length + IV_BYTES
                && Arrays.equals(Arrays.copyOfRange(data, 0, MAGIC_BYTES.length), MAGIC_BYTES);
    }
}
