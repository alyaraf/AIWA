package com.aiwa.util;

/** Admin list search (R4 follow-up: server-driven paging): one rule for turning typed text into a LIKE pattern. */
public final class Searches {

    /** Upper bound of what is searched for: a longer text can never match a short column anyway. */
    private static final int MAX_LENGTH = 100;

    private Searches() {}

    /**
     * Lower-case LIKE pattern, {@code "%"} (match everything) when there is no search. Wildcards the admin typed are
     * dropped rather than escaped, so a search can never become a pattern.
     */
    public static String pattern(String query) {
        if (query == null || query.isBlank()) return "%";
        String q = query.strip().toLowerCase();
        if (q.length() > MAX_LENGTH) q = q.substring(0, MAX_LENGTH);
        q = q.replace("%", "").replace("_", "").replace("\\", "");
        return q.isEmpty() ? "%" : "%" + q + "%";
    }
}
