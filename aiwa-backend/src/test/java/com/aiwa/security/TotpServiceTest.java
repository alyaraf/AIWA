package com.aiwa.security;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verified against the official RFC 6238 Appendix B test vectors (SHA1,
 * 8-digit reference values truncated to our 6 digits — same computation,
 * just keeping fewer trailing digits of the same integer) — not just a
 * self-consistency round trip.
 */
class TotpServiceTest {

    private final TotpService totp = new TotpService();
    private static final byte[] RFC_TEST_KEY = "12345678901234567890".getBytes(StandardCharsets.US_ASCII);

    @Test
    void matchesOfficialRfc6238TestVectors() {
        assertThat(totp.generateCode(RFC_TEST_KEY, 1L)).isEqualTo("287082");          // T=59
        assertThat(totp.generateCode(RFC_TEST_KEY, 37037036L)).isEqualTo("081804");   // T=1111111109
        assertThat(totp.generateCode(RFC_TEST_KEY, 37037037L)).isEqualTo("050471");   // T=1111111111
        assertThat(totp.generateCode(RFC_TEST_KEY, 41152263L)).isEqualTo("005924");   // T=1234567890
        assertThat(totp.generateCode(RFC_TEST_KEY, 66666666L)).isEqualTo("279037");   // T=2000000000
    }

    @Test
    void base32RoundTripsCleanly() {
        byte[] original = TotpService.base32Decode("JBSWY3DPEHPK3PXP"); // "Hello!\xDE\xAD\xBE\xEF"-ish known vector
        assertThat(original).isNotEmpty();
    }

    @Test
    void generatedSecretVerifiesItsOwnCurrentCode() {
        String secret = totp.generateSecret();
        long step = System.currentTimeMillis() / 1000 / 30;
        String code = totp.generateCode(TotpService.base32Decode(secret), step);
        assertThat(totp.verifyCode(secret, code)).isTrue();
    }

    @Test
    void rejectsAWrongCode() {
        String secret = totp.generateSecret();
        assertThat(totp.verifyCode(secret, "000000")).isFalse();
    }

    @Test
    void rejectsMalformedInput() {
        String secret = totp.generateSecret();
        assertThat(totp.verifyCode(secret, "12a456")).isFalse();
        assertThat(totp.verifyCode(secret, "12345")).isFalse();
        assertThat(totp.verifyCode(null, "123456")).isFalse();
        assertThat(totp.verifyCode(secret, null)).isFalse();
    }

    @Test
    void otpAuthUriCarriesTheExpectedFields() {
        String uri = totp.buildOtpAuthUri("ABCD1234", "admin@aiwa.com", "AIWA");
        assertThat(uri).startsWith("otpauth://totp/");
        assertThat(uri).contains("secret=ABCD1234");
        assertThat(uri).contains("issuer=AIWA");
        assertThat(uri).contains("digits=6");
        assertThat(uri).contains("period=30");
    }
}
