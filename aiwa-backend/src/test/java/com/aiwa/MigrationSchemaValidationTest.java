package com.aiwa;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.Arrays;
import java.util.Comparator;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drift guard for the Flyway scripts: runs V1…Vn against an empty database and
 * then boots the application with {@code ddl-auto=validate}, exactly what the
 * prod profile does. Any entity column without a migration (or with the wrong
 * type) fails the context start.
 *
 * <p>It runs on H2 in PostgreSQL mode because CI has no PostgreSQL. PL/pgSQL
 * {@code DO} blocks (constraint clean-ups) and PostgreSQL-only index forms
 * (partial and expression indexes) are skipped or simplified here; they are
 * no-ops for a brand-new database anyway. Run the real scripts against
 * PostgreSQL before a release as well.</p>
 */
@SpringBootTest(properties = {
        "spring.jpa.hibernate.ddl-auto=validate",
        "spring.flyway.enabled=false"
})
@ActiveProfiles("test")
class MigrationSchemaValidationTest {

    private static final String URL =
            "jdbc:h2:mem:migration_check;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH;DB_CLOSE_DELAY=-1";
    private static final Pattern DO_BLOCK = Pattern.compile("DO \\$\\$.*?\\$\\$;", Pattern.DOTALL);
    private static final Pattern STATEMENT_END = Pattern.compile(";\\s*\\r?\\n");

    @DynamicPropertySource
    static void migratedDatabase(DynamicPropertyRegistry registry) throws Exception {
        runMigrations();
        registry.add("spring.datasource.url", () -> URL);
    }

    static void runMigrations() throws Exception {
        try (Connection c = DriverManager.getConnection(URL, "sa", "")) {
            for (Resource script : scripts()) applyScript(c, script);
        }
    }

    /** Every Flyway script, in version order. */
    static Resource[] scripts() throws Exception {
        Resource[] scripts = new PathMatchingResourcePatternResolver().getResources("classpath:db/migration/V*__*.sql");
        Arrays.sort(scripts, Comparator.comparingInt(MigrationSchemaValidationTest::version));
        return scripts;
    }

    /** One script against {@code c} (shared with the migration rehearsal tests). */
    static void applyScript(Connection c, Resource script) throws Exception {
        if (version(script) == 13) dropSingleColumnUniqueOnTermsVersion(c);
        String sql = DO_BLOCK.matcher(new String(script.getInputStream().readAllBytes(), StandardCharsets.UTF_8))
                .replaceAll("");
        try (Statement st = c.createStatement()) {
            for (String raw : STATEMENT_END.split(sql + "\n")) {
                String stmt = h2(stripComments(raw));
                if (stmt == null || stmt.isBlank()) continue;
                try {
                    st.execute(stmt);
                } catch (Exception e) {
                    throw new IllegalStateException(script.getFilename() + " failed at: " + stmt, e);
                }
            }
        }
    }

    static int version(Resource r) {
        String name = r.getFilename();
        return Integer.parseInt(name.substring(1, name.indexOf("__")));
    }

    private static String stripComments(String s) {
        StringBuilder out = new StringBuilder();
        for (String line : s.split("\\r?\\n")) {
            if (!line.trim().startsWith("--")) out.append(line).append('\n');
        }
        return out.toString().trim();
    }

    /** PostgreSQL-only forms → H2 equivalents (or skipped when irrelevant to the schema shape). */
    private static String h2(String stmt) {
        if (stmt.isEmpty()) return null;
        if (stmt.contains("COALESCE(staff_member_id")) return null;           // expression index
        if (stmt.startsWith("CREATE") && stmt.contains(" INDEX ") && stmt.contains(" WHERE ")) {
            return stmt.substring(0, stmt.indexOf(" WHERE "));                // partial index
        }
        return stmt.replace("ON CONFLICT DO NOTHING", "");
    }

    /** What V13's DO block does on PostgreSQL: drop the old UNIQUE(version). */
    private static void dropSingleColumnUniqueOnTermsVersion(Connection c) throws Exception {
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("""
                     SELECT tc.constraint_name FROM information_schema.table_constraints tc
                     JOIN information_schema.key_column_usage k ON k.constraint_name = tc.constraint_name
                     WHERE tc.table_name = 'terms_policies' AND tc.constraint_type = 'UNIQUE'
                       AND k.column_name = 'version'""")) {
            java.util.List<String> names = new java.util.ArrayList<>();
            while (rs.next()) names.add(rs.getString(1));
            for (String n : names) st.execute("ALTER TABLE terms_policies DROP CONSTRAINT \"" + n + "\"");
        }
    }

    @Autowired JdbcTemplate jdbc;

    @Test
    void migrationsProduceTheSchemaTheEntitiesExpect() {
        // Reaching here means Hibernate validated every entity against the migrated schema.
        assertThat(jdbc.queryForObject(
                "SELECT count(*) FROM terms_policies WHERE active = true AND type IN ('CUSTOMER_TERMS','PROVIDER_TERMS')",
                Integer.class)).isEqualTo(2);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM platform_settings", Integer.class)).isEqualTo(1);
    }
}
