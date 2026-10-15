package com.aiwa.util;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * AU-08 / M-3: admin TOTP secrets encrypted at rest (AES-256-GCM). A database
 * dump or backup alone no longer yields working 2FA codes.
 *
 * <p>The key is {@code TOTP_ENCRYPTION_KEY}: 32 bytes, base64. Without it values
 * are stored as before (plain), so nothing breaks before it is configured.
 * Values written before the key existed are read as plain text and encrypted
 * the next time the user row is saved. Encrypted values carry {@value #PREFIX}.
 */
@Converter
public class TotpSecretConverter implements AttributeConverter<String, String> {

    static final String PREFIX = "enc:v1:";
    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final SecretKeySpec key;

    public TotpSecretConverter() {
        this(System.getenv("TOTP_ENCRYPTION_KEY"));
    }

    TotpSecretConverter(String base64Key) {
        if (base64Key == null || base64Key.isBlank()) {
            this.key = null;
        } else {
            byte[] raw = Base64.getDecoder().decode(base64Key.trim());
            if (raw.length != 32) {
                throw new IllegalStateException("TOTP_ENCRYPTION_KEY must be 32 bytes, base64-encoded");
            }
            this.key = new SecretKeySpec(raw, "AES");
        }
    }

    @Override
    public String convertToDatabaseColumn(String secret) {
        if (secret == null || key == null) return secret;
        try {
            byte[] iv = new byte[IV_BYTES];
            RANDOM.nextBytes(iv);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] ct = c.doFinal(secret.getBytes(StandardCharsets.UTF_8));
            return PREFIX + Base64.getEncoder().encodeToString(ByteBuffer.allocate(IV_BYTES + ct.length).put(iv).put(ct).array());
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Could not encrypt the TOTP secret", e);
        }
    }

    @Override
    public String convertToEntityAttribute(String stored) {
        if (stored == null || !stored.startsWith(PREFIX)) return stored; // plain (before the key)
        if (key == null) {
            throw new IllegalStateException("A TOTP secret is encrypted but TOTP_ENCRYPTION_KEY is not set");
        }
        try {
            byte[] all = Base64.getDecoder().decode(stored.substring(PREFIX.length()));
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, all, 0, IV_BYTES));
            return new String(c.doFinal(all, IV_BYTES, all.length - IV_BYTES), StandardCharsets.UTF_8);
        } catch (GeneralSecurityException | IllegalArgumentException e) {
            throw new IllegalStateException("Could not decrypt a TOTP secret (wrong TOTP_ENCRYPTION_KEY?)", e);
        }
    }
}
