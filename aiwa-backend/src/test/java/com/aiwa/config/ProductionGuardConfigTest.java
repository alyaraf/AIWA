package com.aiwa.config;

import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.Profile;
import org.springframework.mock.env.MockEnvironment;

import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * S-01 / S-02: outside local/test the app refuses to start unless it is production-safe, even when a
 * custom JWT secret is set and SPRING_PROFILES_ACTIVE=prod was forgotten.
 */
class ProductionGuardConfigTest {

    private static final String KEY = Base64.getEncoder().encodeToString(new byte[32]);

    private MockEnvironment safeEnv() {
        return new MockEnvironment()
                .withProperty("spring.jpa.hibernate.ddl-auto", "validate")
                .withProperty("springdoc.api-docs.enabled", "false")
                .withProperty("springdoc.swagger-ui.enabled", "false")
                .withProperty("aiwa.sms.provider", "external")
                .withProperty("aiwa.sms.api-url", "https://sms.example.com")
                .withProperty("aiwa.sms.api-key", "k")
                .withProperty("aiwa.email.provider", "http")
                .withProperty("aiwa.email.api-url", "https://mail.example.com")
                .withProperty("aiwa.email.api-key", "k")
                .withProperty("aiwa.push.provider", "none")
                .withProperty("aiwa.safety.oncall-phones", "+201000000000");
    }

    private MockEnvironment prodEnv() {
        MockEnvironment env = safeEnv();
        env.setActiveProfiles("prod");
        return env;
    }

    private Map<String, String> keys() {
        Map<String, String> m = new HashMap<>();
        m.put("TOTP_ENCRYPTION_KEY", KEY);
        m.put("DOCUMENT_ENCRYPTION_KEY", KEY);
        return m;
    }

    private void validate(MockEnvironment env, Map<String, String> secrets) {
        new ProductionGuardConfig(env, secrets::get).validateProductionSettings();
    }

    @Test
    void aFullySafeProdConfigurationStarts() {
        assertThatCode(() -> validate(prodEnv(), keys())).doesNotThrowAnyException();
    }

    @Test
    void refusesWithoutTheProdProfileEvenWhenEverythingElseIsSafe() {
        // A manual deploy with a real JWT secret that forgot SPRING_PROFILES_ACTIVE=prod.
        assertThatThrownBy(() -> validate(safeEnv(), keys()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("SPRING_PROFILES_ACTIVE=prod");
    }

    @Test
    void refusesTheDevDefaultsOfAnUnprofiledDeploy() {
        MockEnvironment dev = new MockEnvironment()
                .withProperty("spring.jpa.hibernate.ddl-auto", "update")
                .withProperty("aiwa.sms.provider", "dev-log")
                .withProperty("aiwa.email.provider", "dev-log")
                .withProperty("aiwa.push.provider", "dev-log");
        assertThatThrownBy(() -> validate(dev, new HashMap<>()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("profile 'prod'")
                .hasMessageContaining("ddl-auto")
                .hasMessageContaining("Swagger")
                .hasMessageContaining("SMS_PROVIDER")
                .hasMessageContaining("EMAIL_PROVIDER")
                .hasMessageContaining("PUSH_PROVIDER")
                .hasMessageContaining("TOTP_ENCRYPTION_KEY")
                .hasMessageContaining("DOCUMENT_ENCRYPTION_KEY");
    }

    @Test
    void theExplicitNonProdEscapeHatchSkipsOnlyTheProfileRule() {
        MockEnvironment staging = safeEnv().withProperty("aiwa.allow-non-prod-server", "true");
        staging.setActiveProfiles("staging");
        assertThatCode(() -> validate(staging, keys())).doesNotThrowAnyException();

        // ...but a staging server still may not run the dev defaults.
        MockEnvironment sloppy = new MockEnvironment().withProperty("aiwa.allow-non-prod-server", "true");
        sloppy.setActiveProfiles("staging");
        assertThatThrownBy(() -> validate(sloppy, keys()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("ddl-auto");
    }

    @Test
    void refusesSchemaMutationAndPublicApiDocs() {
        MockEnvironment update = prodEnv().withProperty("spring.jpa.hibernate.ddl-auto", "update");
        assertThatThrownBy(() -> validate(update, keys())).hasMessageContaining("ddl-auto");

        // Springdoc is on by default, so leaving the switch unset must fail too.
        MockEnvironment unset = new MockEnvironment()
                .withProperty("spring.jpa.hibernate.ddl-auto", "validate")
                .withProperty("aiwa.sms.provider", "external")
                .withProperty("aiwa.sms.api-url", "u").withProperty("aiwa.sms.api-key", "k")
                .withProperty("aiwa.email.provider", "http")
                .withProperty("aiwa.email.api-url", "u").withProperty("aiwa.email.api-key", "k")
                .withProperty("aiwa.push.provider", "none")
                .withProperty("aiwa.safety.oncall-phones", "+20100");
        unset.setActiveProfiles("prod");
        assertThatThrownBy(() -> validate(unset, keys())).hasMessageContaining("Swagger");
    }

    @Test
    void refusesLogOnlyDeliveryAndMissingProviderCredentials() {
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.sms.provider", "dev-log"), keys()))
                .hasMessageContaining("SMS_PROVIDER");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.sms.api-key", ""), keys()))
                .hasMessageContaining("SMS_API_KEY");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.email.provider", "dev-log"), keys()))
                .hasMessageContaining("EMAIL_PROVIDER");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.email.api-key", ""), keys()))
                .hasMessageContaining("EMAIL_API_KEY");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.push.provider", "dev-log"), keys()))
                .hasMessageContaining("PUSH_PROVIDER");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.push.provider", "fcm"), keys()))
                .hasMessageContaining("GOOGLE_APPLICATION_CREDENTIALS");
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.safety.oncall-phones", ""), keys()))
                .hasMessageContaining("SAFETY_ONCALL_PHONES");
    }

    @Test
    void refusesMissingOrMalformedEncryptionKeys() {
        Map<String, String> noTotp = keys();
        noTotp.remove("TOTP_ENCRYPTION_KEY");
        assertThatThrownBy(() -> validate(prodEnv(), noTotp)).hasMessageContaining("TOTP_ENCRYPTION_KEY is required");

        Map<String, String> noDoc = keys();
        noDoc.put("DOCUMENT_ENCRYPTION_KEY", "  ");
        assertThatThrownBy(() -> validate(prodEnv(), noDoc)).hasMessageContaining("DOCUMENT_ENCRYPTION_KEY is required");

        Map<String, String> short16 = keys();
        short16.put("TOTP_ENCRYPTION_KEY", Base64.getEncoder().encodeToString(new byte[16]));
        assertThatThrownBy(() -> validate(prodEnv(), short16)).hasMessageContaining("32 bytes");

        Map<String, String> notBase64 = keys();
        notBase64.put("DOCUMENT_ENCRYPTION_KEY", "not base64 !!");
        assertThatThrownBy(() -> validate(prodEnv(), notBase64)).hasMessageContaining("32 bytes");
    }

    @Test
    void theGuardCoversEveryProfileExceptLocalAndTest() {
        // The guard must not be prod-only, or a forgotten profile flag skips it.
        assertThat(ProductionGuardConfig.class.getAnnotation(Profile.class).value()).containsExactly("!local & !test");
    }

    /** P-02: a configured SMS/e-mail gateway has to be a public https host. */
    @Test
    void refusesGatewayUrlsThatAreNotPublicHttps() {
        for (String bad : new String[]{"http://sms.example.com", "https://localhost/send", "https://127.0.0.1/send",
                "https://10.0.0.5/send", "https://192.168.1.9/x", "https://169.254.169.254/latest", "https://[::1]/x",
                "https://user:pw@sms.example.com", "https://db.internal/x", "not a url"}) {
            assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.sms.api-url", bad), keys()))
                    .as(bad).isInstanceOf(IllegalStateException.class).hasMessageContaining("SMS_API_URL");
            assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.email.api-url", bad), keys()))
                    .as(bad).isInstanceOf(IllegalStateException.class).hasMessageContaining("EMAIL_API_URL");
        }
    }

    @Test
    void anOptionalHostAllowListIsEnforced() {
        MockEnvironment listed = prodEnv().withProperty("aiwa.gateway.allowed-hosts", "sms.example.com, .mailer.test");
        listed.withProperty("aiwa.email.api-url", "https://eu.mailer.test/v1");
        assertThatCode(() -> validate(listed, keys())).doesNotThrowAnyException();
        assertThatThrownBy(() -> validate(prodEnv().withProperty("aiwa.gateway.allowed-hosts", "other.example.org"), keys()))
                .hasMessageContaining("AIWA_GATEWAY_ALLOWED_HOSTS");
    }
}
