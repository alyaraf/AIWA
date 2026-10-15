package com.aiwa.support;

import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicLong;

/**
 * R7-14: one phone source for every test that saves a user. On H2 each new Spring context recreates the schema, but on
 * PostgreSQL (CI, Flyway + validate) committed users live for the whole run, so per-class prefixes with counters that
 * all start at 1 collided on users_phone_key. One JVM-wide counter, starting at a random offset so leftovers from an
 * earlier run on a kept local database are unlikely to clash, gives every call a distinct E.164 number.
 */
public final class TestPhones {

    // ponytail: random start, not a DB lookup; a rerun on a kept database clashes only if two runs overlap in 80M numbers
    private static final AtomicLong SEQ = new AtomicLong(ThreadLocalRandom.current().nextLong(10_000_000L, 90_000_000L));

    private TestPhones() {}

    /** A fresh Egyptian mobile number, already in the form Identifiers.normalizePhone produces. */
    public static String next() {
        return "+2010" + String.format("%08d", SEQ.incrementAndGet());
    }
}
