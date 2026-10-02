package com.aiwa.config;

import com.aiwa.util.Identifiers;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.UnaryOperator;

/**
 * CR-02: rewrites stored emails (trimmed, lower case) and phones
 * ({@link Identifiers#normalizePhone}) to the one spelling sign-in looks up.
 *
 * <p>A Java migration, not SQL, so the phone rule is the application's own code
 * instead of a second copy in two SQL dialects. Spring Boot hands every
 * {@code JavaMigration} bean to Flyway, which is why this is a component.</p>
 *
 * <p>A row whose new value would run into another account is left exactly as
 * stored and written to {@code identifier_collisions} for a person to resolve.
 * Nothing is merged or deleted, and a second run changes nothing more. The
 * UNIQUE constraints V1 put on users.email and users.phone already are the
 * unique indexes on the normalised values, so none is added.</p>
 */
@Component
public class V19__Normalise_identifiers extends BaseJavaMigration {

    @Override
    public void migrate(Context context) throws SQLException {
        run(context.getConnection());
    }

    static void run(Connection c) throws SQLException {
        try (Statement st = c.createStatement()) {
            // No foreign key to users: an admin account can still be hard-deleted.
            st.execute("CREATE TABLE IF NOT EXISTS identifier_collisions ("
                    + "id bigserial PRIMARY KEY, "
                    + "user_id bigint NOT NULL, "
                    + "kind varchar(8) NOT NULL, "
                    + "stored_value varchar(255) NOT NULL, "
                    + "normalised_value varchar(255) NOT NULL, "
                    + "conflicts_with_user_id bigint NOT NULL, "
                    + "found_at timestamp(6) NOT NULL DEFAULT now())");
        }
        // Not Identifiers.normalizeEmail: it rejects a stored value that is not an
        // email, and a migration must not fail on old data.
        normalise(c, "EMAIL", "email", v -> v.isBlank() ? null : v.trim().toLowerCase(Locale.ROOT));
        normalise(c, "PHONE", "phone", Identifiers::normalizePhone);
    }

    private record Row(long id, String stored) {
    }

    // ponytail: reads every user's id and one column into memory; page it if the table outgrows that.
    private static void normalise(Connection c, String kind, String column, UnaryOperator<String> rule)
            throws SQLException {
        Map<String, List<Row>> byNormalised = new LinkedHashMap<>();
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT id, " + column + " FROM users WHERE " + column
                     + " IS NOT NULL ORDER BY id")) {
            while (rs.next()) {
                String normalised = rule.apply(rs.getString(2));
                if (normalised == null) continue; // blank: nothing to normalise
                byNormalised.computeIfAbsent(normalised, k -> new ArrayList<>())
                        .add(new Row(rs.getLong(1), rs.getString(2)));
            }
        }
        try (PreparedStatement update = c.prepareStatement("UPDATE users SET " + column + " = ? WHERE id = ?");
             PreparedStatement known = c.prepareStatement(
                     "SELECT count(*) FROM identifier_collisions WHERE user_id = ? AND kind = ?");
             PreparedStatement report = c.prepareStatement("INSERT INTO identifier_collisions "
                     + "(user_id, kind, stored_value, normalised_value, conflicts_with_user_id) VALUES (?, ?, ?, ?, ?)")) {
            for (Map.Entry<String, List<Row>> e : byNormalised.entrySet()) {
                String normalised = e.getKey();
                List<Row> rows = e.getValue();
                for (Row row : rows) {
                    if (row.stored().equals(normalised)) continue;
                    if (rows.size() == 1) {
                        update.setString(1, normalised);
                        update.setLong(2, row.id());
                        update.executeUpdate();
                        continue;
                    }
                    known.setLong(1, row.id());
                    known.setString(2, kind);
                    try (ResultSet rs = known.executeQuery()) {
                        rs.next();
                        if (rs.getInt(1) > 0) continue; // reported by an earlier run
                    }
                    // The account already holding the normalised value, else the oldest other one.
                    long other = rows.stream().filter(o -> o.stored().equals(normalised)).findFirst()
                            .orElseGet(() -> rows.stream().filter(o -> o.id() != row.id()).findFirst().orElseThrow())
                            .id();
                    report.setLong(1, row.id());
                    report.setString(2, kind);
                    report.setString(3, row.stored());
                    report.setString(4, normalised);
                    report.setLong(5, other);
                    report.executeUpdate();
                }
            }
        }
    }

    /** One WARN line at startup while collisions are waiting to be resolved; ids stay in the table. */
    @Slf4j
    @Component
    @RequiredArgsConstructor
    public static class StartupLog implements ApplicationRunner {

        private final JdbcTemplate jdbc;

        @Override
        public void run(ApplicationArguments args) {
            Integer count;
            try {
                count = jdbc.queryForObject("SELECT count(*) FROM identifier_collisions", Integer.class);
            } catch (DataAccessException e) {
                return; // no table: Flyway is off (local, tests)
            }
            if (count != null && count > 0) {
                log.warn("{} rows in identifier_collisions: these accounts keep an email or phone that is not in "
                        + "the normalised spelling because another account already has it. Resolve each by hand "
                        + "(SELECT user_id, kind, conflicts_with_user_id FROM identifier_collisions).", count);
            }
        }
    }
}
