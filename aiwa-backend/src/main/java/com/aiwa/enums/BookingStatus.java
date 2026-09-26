package com.aiwa.enums;

public enum BookingStatus {
    PENDING,
    ACCEPTED,
    REJECTED,
    EXPIRED,
    ON_THE_WAY,
    ARRIVED,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED,
    NO_SHOW;

    /**
     * Valid transitions map. Supports both service topologies:
     *  - Home service:   ACCEPTED → ON_THE_WAY → ARRIVED → IN_PROGRESS → COMPLETED
     *  - On-site / venue: ACCEPTED → IN_PROGRESS → COMPLETED (customer checks in)
     * NO_SHOW is reachable wherever a party can be found absent (ACCEPTED venue
     * check-in, or ARRIVED for home service). EXPIRED is a system-only terminal
     * state for a PENDING request the provider never answered.
     */
    public boolean canTransitionTo(BookingStatus next) {
        return switch (this) {
            case PENDING    -> next == ACCEPTED || next == REJECTED
                            || next == CANCELLED || next == EXPIRED;
            case ACCEPTED   -> next == ON_THE_WAY || next == IN_PROGRESS
                            || next == NO_SHOW || next == CANCELLED;
            case ON_THE_WAY -> next == ARRIVED || next == CANCELLED;
            case ARRIVED    -> next == IN_PROGRESS || next == NO_SHOW || next == CANCELLED;
            case IN_PROGRESS -> next == COMPLETED;
            default         -> false;
        };
    }

    /** Terminal states that no longer occupy a provider's time slot. */
    public boolean isSlotReleasing() {
        return this == CANCELLED || this == REJECTED || this == EXPIRED;
    }
}
