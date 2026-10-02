package com.aiwa.security;

import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.Locale;

/**
 * RFC 6238 TOTP (the algorithm behind Google Authenticator / Authy / 1Password
 * codes) implemented directly against the JDK's HMAC support — no external
 * library needed. 30-second time step, 6-digit codes, SHA-1 (the universal
 * default every authenticator app assumes unless told otherwise).
 */
@Component
public class TotpService {

    private static final int SECRET_BYTES = 20; // 160-bit, standard for TOTP
    private static final int TIME_STEP_SECONDS = 30;
    private static final int CODE_DIGITS = 6;
    // ±1 time-step = ±30s tolerance, the RFC 6238 recommendation: three codes are
    // valid at any moment. It was ±3 (seven codes), which made guessing easier (CR-01).
    private static final int ALLOWED_DRIFT_STEPS = 1;
    private static final String BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    private final SecureRandom random = new SecureRandom();

    /** Length of one time step, for clients that show a clock hint. */
    public static int stepSeconds() {
        return TIME_STEP_SECONDS;
    }

    /**
     * How far a phone's clock may be off before every code is refused. Derived
     * from the constants verification uses, so what clients are told cannot
     * differ from the real check (it said 90 s after the drift was cut to 30 s).
     */
    public static int driftToleranceSeconds() {
        return ALLOWED_DRIFT_STEPS * TIME_STEP_SECONDS;
    }

    /** A fresh Base32-encoded secret — store it, show it to the user once, never log it. */
    public String generateSecret() {
        byte[] bytes = new byte[SECRET_BYTES];
        random.nextBytes(bytes);
        return base32Encode(bytes);
    }

    /** The URI an authenticator app's "scan / enter manually" flow expects. */
    public String buildOtpAuthUri(String secret, String accountLabel, String issuer) {
        return String.format(Locale.ROOT,
                "otpauth://totp/%s:%s?secret=%s&issuer=%s&algorithm=SHA1&digits=%d&period=%d",
                urlEncode(issuer), urlEncode(accountLabel), secret, urlEncode(issuer), CODE_DIGITS, TIME_STEP_SECONDS);
    }

    /** True if {@code code} matches the secret at the current time step, or one step either side. */
    public boolean verifyCode(String secret, String code) {
        return matchingStep(secret, code) != null;
    }

    /**
     * The time step {@code code} belongs to, or null when it matches none of the
     * allowed ones. Callers store the step of an accepted code and refuse that
     * step (and older ones) afterwards, so a code works once (CR-01).
     */
    public Long matchingStep(String secret, String code) {
        if (secret == null || code == null || !code.matches("\\d{6}")) return null;
        long currentStep = System.currentTimeMillis() / 1000 / TIME_STEP_SECONDS;
        byte[] key = base32Decode(secret);
        for (int drift = -ALLOWED_DRIFT_STEPS; drift <= ALLOWED_DRIFT_STEPS; drift++) {
            if (generateCode(key, currentStep + drift).equals(code)) return currentStep + drift;
        }
        return null;
    }

    // package-private (not private) so TotpServiceTest can check against the
    // official RFC 6238 Appendix B test vectors directly, not just round-trip.
    String generateCode(byte[] key, long timeStep) {
        try {
            byte[] data = ByteBuffer.allocate(8).putLong(timeStep).array();
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(key, "HmacSHA1"));
            byte[] hash = mac.doFinal(data);

            int offset = hash[hash.length - 1] & 0x0F;
            int binary = ((hash[offset] & 0x7F) << 24)
                    | ((hash[offset + 1] & 0xFF) << 16)
                    | ((hash[offset + 2] & 0xFF) << 8)
                    | (hash[offset + 3] & 0xFF);
            int otp = binary % (int) Math.pow(10, CODE_DIGITS);
            return String.format(Locale.ROOT, "%0" + CODE_DIGITS + "d", otp);
        } catch (Exception e) {
            throw new IllegalStateException("Could not compute TOTP code", e);
        }
    }

    private static String base32Encode(byte[] data) {
        StringBuilder sb = new StringBuilder();
        int bits = 0, value = 0;
        for (byte b : data) {
            value = (value << 8) | (b & 0xFF);
            bits += 8;
            while (bits >= 5) {
                sb.append(BASE32_ALPHABET.charAt((value >>> (bits - 5)) & 0x1F));
                bits -= 5;
            }
        }
        if (bits > 0) {
            sb.append(BASE32_ALPHABET.charAt((value << (5 - bits)) & 0x1F));
        }
        return sb.toString();
    }

    static byte[] base32Decode(String encoded) {
        String clean = encoded.trim().toUpperCase(Locale.ROOT).replace("=", "");
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        int bits = 0, value = 0;
        for (char c : clean.toCharArray()) {
            int idx = BASE32_ALPHABET.indexOf(c);
            if (idx < 0) continue;
            value = (value << 5) | idx;
            bits += 5;
            if (bits >= 8) {
                out.write((value >>> (bits - 8)) & 0xFF);
                bits -= 8;
            }
        }
        return out.toByteArray();
    }

    private static String urlEncode(String s) {
        return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8).replace("+", "%20");
    }
}
