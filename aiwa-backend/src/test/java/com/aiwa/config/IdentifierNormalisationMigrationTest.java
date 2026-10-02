package com.aiwa.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.sql.Connection;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * CR-02: V19 rewrites stored emails and phones to the one spelling sign-in looks
 * up, and leaves alone (and reports) every row it cannot rewrite without
 * running into another account. H2 in PostgreSQL mode, like
 * MigrationSchemaValidationTest.
 */
@ExtendWith(OutputCaptureExtension.class)
class IdentifierNormalisationMigrationTest {

    private final DriverManagerDataSource ds = new DriverManagerDataSource(
            "jdbc:h2:mem:v19_check;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1", "sa", "");
    private final JdbcTemplate jdbc = new JdbcTemplate(ds);

    @BeforeEach
    void seed() {
        jdbc.execute("DROP TABLE IF EXISTS identifier_collisions");
        jdbc.execute("DROP TABLE IF EXISTS users");
        jdbc.execute("CREATE TABLE users (id bigint PRIMARY KEY, email varchar(255) UNIQUE, phone varchar(255) UNIQUE)");
        user(1, " Nour@X.com", "01012345678");          // both rewritten
        user(2, "layla@x.com", "+201000000002");        // already in the one spelling
        user(3, "Sara@x.com", "0100 000-0003");         // would run into user 4 on both
        user(4, "sara@x.com", "+201000000003");
        user(5, "Mona@x.com", "01000000005");           // 5 and 6 run into each other,
        user(6, "MONA@x.com", "00201000000005");        // neither is in the one spelling
        user(7, null, null);
        user(8, "not an email", "ext. 12");             // not an email, not a number
    }

    private void user(long id, String email, String phone) {
        jdbc.update("INSERT INTO users (id, email, phone) VALUES (?, ?, ?)", id, email, phone);
    }

    private void migrate() throws Exception {
        try (Connection c = ds.getConnection()) {
            V19__Normalise_identifiers.run(c);
        }
    }

    private List<Map<String, Object>> users() {
        return jdbc.queryForList("SELECT id, email, phone FROM users ORDER BY id");
    }

    private List<Map<String, Object>> collisions() {
        return jdbc.queryForList("SELECT user_id, kind, stored_value, normalised_value, conflicts_with_user_id "
                + "FROM identifier_collisions ORDER BY kind, user_id");
    }

    private static Map<String, Object> row(long id, String email, String phone) {
        Map<String, Object> m = new java.util.HashMap<>();
        m.put("id", id);
        m.put("email", email);
        m.put("phone", phone);
        return m;
    }

    private static Map<String, Object> collision(long userId, String kind, String stored, String norm, long other) {
        return Map.of("user_id", userId, "kind", kind, "stored_value", stored,
                "normalised_value", norm, "conflicts_with_user_id", other);
    }

    @Test
    void storedIdentifiersAreRewrittenUnlessTheyWouldRunIntoAnotherAccount() throws Exception {
        migrate();

        assertThat(users()).containsExactly(
                row(1, "nour@x.com", "+201012345678"),
                row(2, "layla@x.com", "+201000000002"),
                row(3, "Sara@x.com", "0100 000-0003"),
                row(4, "sara@x.com", "+201000000003"),
                row(5, "Mona@x.com", "01000000005"),
                row(6, "MONA@x.com", "00201000000005"),
                row(7, null, null),
                row(8, "not an email", "ext.12"));               // what normalizePhone gives a non-number
        // One row per account left as stored, naming the account it would run into.
        assertThat(collisions()).containsExactly(
                collision(3, "EMAIL", "Sara@x.com", "sara@x.com", 4),
                collision(5, "EMAIL", "Mona@x.com", "mona@x.com", 6),
                collision(6, "EMAIL", "MONA@x.com", "mona@x.com", 5),
                collision(3, "PHONE", "0100 000-0003", "+201000000003", 4),
                collision(5, "PHONE", "01000000005", "+201000000005", 6),
                collision(6, "PHONE", "00201000000005", "+201000000005", 5));
    }

    @Test
    void runningItTwiceChangesNothingMore() throws Exception {
        migrate();
        List<Map<String, Object>> users = users();
        List<Map<String, Object>> collisions = collisions();
        assertThat(collisions).hasSize(6);

        migrate();

        assertThat(users()).isEqualTo(users);
        assertThat(collisions()).isEqualTo(collisions);
    }

    @Test
    void startupWarnsWithTheCountAndNoPersonalData(CapturedOutput out) throws Exception {
        migrate();

        new V19__Normalise_identifiers.StartupLog(jdbc).run(null);

        assertThat(out.getAll()).contains("6 rows in identifier_collisions");
        assertThat(out.getAll()).doesNotContain("x.com").doesNotContain("0100");
    }

    @Test
    void startupSaysNothingWithoutCollisionsOrWithoutTheTable(CapturedOutput out) throws Exception {
        jdbc.execute("DROP TABLE IF EXISTS identifier_collisions");
        new V19__Normalise_identifiers.StartupLog(jdbc).run(null);      // Flyway off: no table
        jdbc.update("DELETE FROM users WHERE id IN (3, 5, 6)");
        migrate();
        new V19__Normalise_identifiers.StartupLog(jdbc).run(null);      // table there, empty

        assertThat(jdbc.queryForObject("SELECT count(*) FROM identifier_collisions", Integer.class)).isZero();
        assertThat(out.getAll()).doesNotContain("identifier_collisions");
    }
}
