package com.aiwa.enums;

import org.junit.jupiter.api.Test;

import static com.aiwa.enums.BookingStatus.*;
import static org.assertj.core.api.Assertions.assertThat;

/** Locks down the booking state machine against the documented flow. */
class BookingStatusTransitionTest {

    @Test
    void homeServicePath() {
        assertThat(ACCEPTED.canTransitionTo(ON_THE_WAY)).isTrue();
        assertThat(ON_THE_WAY.canTransitionTo(ARRIVED)).isTrue();
        assertThat(ARRIVED.canTransitionTo(IN_PROGRESS)).isTrue();
        assertThat(IN_PROGRESS.canTransitionTo(COMPLETED)).isTrue();
    }

    @Test
    void onSitePathCanStartWithoutTravelLegs() {
        // The bug: on-site bookings could never leave ACCEPTED.
        assertThat(ACCEPTED.canTransitionTo(IN_PROGRESS)).isTrue();
    }

    @Test
    void noShowReachableWhereFlowExpectsIt() {
        assertThat(ARRIVED.canTransitionTo(NO_SHOW)).isTrue();   // home service
        assertThat(ACCEPTED.canTransitionTo(NO_SHOW)).isTrue();  // on-site check-in
    }

    @Test
    void pendingCanExpire() {
        assertThat(PENDING.canTransitionTo(EXPIRED)).isTrue();
        assertThat(PENDING.canTransitionTo(ACCEPTED)).isTrue();
        assertThat(PENDING.canTransitionTo(REJECTED)).isTrue();
        assertThat(PENDING.canTransitionTo(CANCELLED)).isTrue();
    }

    @Test
    void illegalTransitionsRejected() {
        assertThat(COMPLETED.canTransitionTo(IN_PROGRESS)).isFalse();
        assertThat(EXPIRED.canTransitionTo(ACCEPTED)).isFalse();
        assertThat(PENDING.canTransitionTo(IN_PROGRESS)).isFalse();
        assertThat(IN_PROGRESS.canTransitionTo(NO_SHOW)).isFalse();
    }

    @Test
    void slotReleasingStates() {
        assertThat(CANCELLED.isSlotReleasing()).isTrue();
        assertThat(REJECTED.isSlotReleasing()).isTrue();
        assertThat(EXPIRED.isSlotReleasing()).isTrue();
        assertThat(ACCEPTED.isSlotReleasing()).isFalse();
        assertThat(COMPLETED.isSlotReleasing()).isFalse();
    }
}
