package com.aiwa.util;

import java.util.regex.Pattern;

/**
 * I-06: provider and driver exception messages can echo the request (a phone number, an e-mail address, a bearer
 * token). Anything that comes from outside is passed through here before it is logged.
 */
public final class LogSafe {

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern PHONE = Pattern.compile("\\+?\\d[\\d\\s().-]{7,}\\d");
    private static final Pattern SECRET = Pattern.compile(
            "(?i)(bearer|token|key|secret|password)([\"'=:\\s]+)[A-Za-z0-9._~+/=-]{8,}");
    private static final int MAX = 300;

    private LogSafe() {}

    public static String scrub(String message) {
        if (message == null) return "";
        String s = EMAIL.matcher(message).replaceAll("<email>");
        s = SECRET.matcher(s).replaceAll("$1$2<redacted>");
        s = PHONE.matcher(s).replaceAll("<number>");
        s = oneLine(s);
        return s.length() > MAX ? s.substring(0, MAX) + "…" : s;
    }

    /**
     * Request-supplied text on one line, so it cannot forge extra log entries. CodeQL's java/log-injection only
     * accepts replaceAll with exactly "\\R", "\\n" or "\\r" as a sanitizer, so keep this pattern literal.
     */
    public static String oneLine(String s) {
        return s == null ? "" : s.replaceAll("\\R", " ");
    }
}
