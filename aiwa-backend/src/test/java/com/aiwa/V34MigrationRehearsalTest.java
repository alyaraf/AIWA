package com.aiwa;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.Resource;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Rehearsal of migration V34 (booking destination snapshot, B-05) on disposable, representative data.
 *
 * <p>The database is built to the V33 schema, filled with the kinds of rows production holds (home visits with edited,
 * default and archived addresses; venue visits with no address; a booking whose address was deleted), and then V34 is
 * applied. It proves the backfill rule and its provenance flag, idempotence, and rollback compatibility (the previous
 * release can still write bookings against the migrated schema). It runs on H2 in PostgreSQL mode like
 * {@link MigrationSchemaValidationTest}; the same rehearsal on a COPY OF PRODUCTION DATA in real PostgreSQL is still launch
 * gate 27 (no PostgreSQL is available on this machine).</p>
 */
class V34MigrationRehearsalTest {

    private static final String URL =
            "jdbc:h2:mem:v34_rehearsal;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH;DB_CLOSE_DELAY=-1";

    private static long q(Connection c, String sql) throws Exception {
        try (Statement st = c.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            rs.next();
            return rs.getLong(1);
        }
    }

    /** Inserts one row, filling every other NOT NULL column that has no default with a harmless value; returns its id. */
    private static long insert(Connection c, String table, Map<String, Object> values) throws Exception {
        Map<String, Object> row = new LinkedHashMap<>(values);
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ? AND is_nullable = 'NO' "
                        + "AND column_default IS NULL AND is_identity = 'NO'")) {
            ps.setString(1, table);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String col = rs.getString(1);
                    if (row.containsKey(col)) continue;
                    String type = rs.getString(2).toLowerCase();
                    row.put(col, type.contains("char") ? "x" : type.contains("boolean") ? Boolean.FALSE
                            : type.contains("timestamp") ? Timestamp.from(Instant.now())
                            : type.equals("date") ? java.sql.Date.valueOf("2026-12-01")
                            : type.startsWith("time") ? java.sql.Time.valueOf("10:00:00") : (Object) 0);
                }
            }
        }
        List<String> cols = new ArrayList<>(row.keySet());
        String sql = "INSERT INTO " + table + " (" + String.join(",", cols) + ") VALUES ("
                + "?,".repeat(cols.size() - 1) + "?)";
        try (PreparedStatement ps = c.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            for (int i = 0; i < cols.size(); i++) ps.setObject(i + 1, row.get(cols.get(i)));
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                keys.next();
                return keys.getLong(1);
            }
        }
    }

    private static Map<String, Object> m(Object... kv) {
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) map.put((String) kv[i], kv[i + 1]);
        return map;
    }

    @Test
    void backfillCopiesTheCurrentAddressMarksProvenanceAndLeavesEverythingElseAlone() throws Exception {
        try (Connection c = DriverManager.getConnection(URL, "sa", "")) {
            Resource v34 = null;
            for (Resource script : MigrationSchemaValidationTest.scripts()) {
                if (MigrationSchemaValidationTest.version(script) == 34) { v34 = script; break; }
                MigrationSchemaValidationTest.applyScript(c, script);
            }
            assertThat(v34).as("V34 exists").isNotNull();
            // the schema as the previous release sees it: no destination columns yet
            assertThat(q(c, "SELECT count(*) FROM information_schema.columns WHERE table_name = 'bookings' AND column_name LIKE 'destination%'")).isZero();

            long customer = insert(c, "users", m("email", "c@x.test", "phone", "+201000000001", "role", "CUSTOMER", "full_name", "C"));
            long owner = insert(c, "users", m("email", "p@x.test", "phone", "+201000000002", "role", "PROVIDER", "full_name", "P"));
            long provider = insert(c, "provider_profiles", m("user_id", owner, "business_name", "Studio"));
            long service = insert(c, "services", m("provider_id", provider, "name", "Cut", "price", 100, "duration_minutes", 30));
            long home = insert(c, "saved_addresses", m("user_id", customer, "label", "Home", "address_line", "1 Nile St (EDITED after booking)", "latitude", 30.07, "longitude", 31.23));
            long archived = insert(c, "saved_addresses", m("user_id", customer, "label", "Old", "address_line", "9 Old Rd", "latitude", 30.0, "longitude", 31.0));
            long homeA = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "saved_address_id", home, "home_service", true, "status", "COMPLETED"));
            long homeB = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "saved_address_id", home, "home_service", true, "status", "ACCEPTED"));
            long onArchived = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "saved_address_id", archived, "home_service", true, "status", "COMPLETED"));
            long venue = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "home_service", false, "status", "COMPLETED"));
            long homeNoAddress = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "home_service", true, "status", "CANCELLED"));

            MigrationSchemaValidationTest.applyScript(c, v34);

            // every row with a saved address got a snapshot, marked as reconstructed (the agreed text was never recorded)
            for (long id : new long[]{homeA, homeB}) {
                try (Statement st = c.createStatement(); ResultSet rs = st.executeQuery(
                        "SELECT destination_label, destination_address, destination_latitude, destination_longitude, destination_backfilled, destination_amended_at FROM bookings WHERE id = " + id)) {
                    rs.next();
                    assertThat(rs.getString(1)).isEqualTo("Home");
                    assertThat(rs.getString(2)).isEqualTo("1 Nile St (EDITED after booking)");
                    assertThat(rs.getDouble(3)).isEqualTo(30.07);
                    assertThat(rs.getDouble(4)).isEqualTo(31.23);
                    assertThat(rs.getBoolean(5)).as("provenance: copied now, not recorded at booking time").isTrue();
                    assertThat(rs.getObject(6)).as("a backfill is not an amendment").isNull();
                }
            }
            assertThat(q(c, "SELECT count(*) FROM bookings WHERE id = " + onArchived + " AND destination_address = '9 Old Rd' AND destination_backfilled = true")).isEqualTo(1);
            // venue visits and a home visit with no address are left exactly as they were, not flagged
            for (long id : new long[]{venue, homeNoAddress}) {
                assertThat(q(c, "SELECT count(*) FROM bookings WHERE id = " + id + " AND destination_address IS NULL AND destination_backfilled = false")).isEqualTo(1);
            }
            // the share the runbook asks the operator to read before deploying: 3 of 5 here
            assertThat(q(c, "SELECT count(*) FROM bookings WHERE destination_backfilled = true")).isEqualTo(3);
            assertThat(q(c, "SELECT count(*) FROM bookings")).isEqualTo(5);

            // idempotent: running it again changes nothing, and an amended (non-backfilled) snapshot is never overwritten
            c.createStatement().execute("UPDATE bookings SET destination_address = '5 Tahrir Sq (amended)', destination_backfilled = false, destination_amended_at = now() WHERE id = " + homeB);
            MigrationSchemaValidationTest.applyScript(c, v34);
            assertThat(q(c, "SELECT count(*) FROM bookings WHERE id = " + homeB + " AND destination_address = '5 Tahrir Sq (amended)' AND destination_backfilled = false")).isEqualTo(1);
            assertThat(q(c, "SELECT count(*) FROM bookings WHERE destination_backfilled = true")).isEqualTo(2);

            // rollback compatibility: the PREVIOUS release inserts bookings without the new columns; the schema accepts it and
            // the row reads as "no snapshot", which BookingPrivacy.destinationOf resolves from the live saved address.
            long legacy = insert(c, "bookings", m("customer_id", customer, "provider_id", provider, "service_id", service, "saved_address_id", home, "home_service", true, "status", "PENDING"));
            assertThat(q(c, "SELECT count(*) FROM bookings WHERE id = " + legacy + " AND destination_address IS NULL AND destination_backfilled = false")).isEqualTo(1);
        }
    }
}
