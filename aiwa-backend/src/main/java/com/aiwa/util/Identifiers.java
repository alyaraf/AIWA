package com.aiwa.util;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * One spelling per email and phone (R2-19), and a login lookup that can never
 * mistake one for the other (V-01).
 *
 * <p>Before, "Nour@x.com" and "nour@x.com", or "+201012345678" and "01012345678",
 * became separate accounts, and every lookup tried the value as an email first
 * and then as a phone. A user could set their email to someone else's phone
 * number and from then on that person's sign-in, refresh and saved data
 * resolved to the attacker's account.</p>
 */
public final class Identifiers {

    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

    private Identifiers() {
    }

    /** Lower-cased, trimmed email, or null when blank. Throws when it isn't an email address. */
    public static String normalizeEmail(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim().toLowerCase(Locale.ROOT);
        if (!EMAIL.matcher(v).matches()) throw new IllegalArgumentException("not an email address");
        return v;
    }

    /**
     * Egyptian numbers in E.164 (+20…), other numbers with their + prefix kept.
     * Accepts 01xxxxxxxxx, 201xxxxxxxxx, 00201xxxxxxxxx, +2001xxxxxxxxx and
     * spaces or dashes. Returns null when blank.
     */
    public static String normalizePhone(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim().replaceAll("[\\s\\-()]", "");
        boolean plus = v.startsWith("+");
        String digits = (plus ? v.substring(1) : v);
        if (!digits.matches("\\d+")) return v; // not a phone number; let validation reject it
        if (!plus && digits.startsWith("00")) {
            digits = digits.substring(2);
            plus = true;
        }
        if (!plus && digits.length() == 11 && digits.startsWith("01")) {
            return "+20" + digits.substring(1);
        }
        if (digits.startsWith("200") && digits.length() == 13) {
            digits = "20" + digits.substring(3); // "+20" typed in front of a local 0…
        }
        if (!plus && digits.length() == 12 && digits.startsWith("201")) {
            return "+" + digits;
        }
        return plus ? "+" + digits : digits;
    }

    /** A login identifier is an email exactly when it contains "@"; anything else is a phone. */
    public static boolean isEmail(String identifier) {
        return identifier != null && identifier.contains("@");
    }
}
