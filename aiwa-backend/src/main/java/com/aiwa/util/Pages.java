package com.aiwa.util;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * Clamped paging for request parameters (BE-40): {@code page=-1} used to throw a
 * generic 500 and {@code size=1000000} loaded a whole table in one request.
 */
public final class Pages {

    /** App-facing lists. */
    public static final int MAX_SIZE = 100;
    /** Admin lists: the admin panel still loads up to 500 rows and filters in the browser. */
    public static final int ADMIN_MAX_SIZE = 500;

    private Pages() {}

    public static Pageable of(int page, int size) {
        return clamp(page, size, MAX_SIZE, Sort.unsorted());
    }

    public static Pageable admin(int page, int size) {
        return clamp(page, size, ADMIN_MAX_SIZE, Sort.unsorted());
    }

    public static Pageable admin(int page, int size, Sort sort) {
        return clamp(page, size, ADMIN_MAX_SIZE, sort);
    }

    private static Pageable clamp(int page, int size, int max, Sort sort) {
        return PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, max)), sort);
    }
}
