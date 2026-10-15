package com.aiwa.service.impl;

/** Great-circle distance helper shared by discovery and the waitlist. */
public final class GeoUtils {

    private GeoUtils() {}

    public static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
        if (!(Math.abs(lat1) <= 90 && Math.abs(lat2) <= 90 && Math.abs(lon1) <= 180 && Math.abs(lon2) <= 180)) {
            throw new IllegalArgumentException("coordinates out of range"); // callers pass validated values
        }
        final int r = 6371;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
