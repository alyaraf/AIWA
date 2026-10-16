package com.aiwa.service.impl;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.SavedAddress;
import com.aiwa.enums.ProviderType;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * AQ-05: the Book Now arrival estimate reached the customer before acceptance and used a home-based provider's
 * exact pin, a distance oracle about 0.3 km fine where the public reads round the pin to about 500 m.
 */
class BookNowArrivalEstimateTest {

    private static final SavedAddress CUSTOMER = SavedAddress.builder().latitude(30.105).longitude(31.220).build();

    private static ProviderProfile at(ProviderType type, double latitude) {
        return ProviderProfile.builder().providerType(type).latitude(latitude).longitude(31.220).build();
    }

    @Test
    void aHomeBasedProviderIsTimedFromTheRoundedPin() {
        // 30.062 rounds to the 30.060 grid point: about 4.8 km exact, 5.0 km rounded.
        assertThat(BookingServiceImpl.estimateArrivalMinutes(at(ProviderType.INDIVIDUAL, 30.062), CUSTOMER))
                .isEqualTo(BookingServiceImpl.estimateArrivalMinutes(at(ProviderType.INDIVIDUAL, 30.060), CUSTOMER))
                .isEqualTo(25);
    }

    @Test
    void aShopIsTimedFromItsExactLocation() {
        assertThat(BookingServiceImpl.estimateArrivalMinutes(at(ProviderType.SHOP, 30.062), CUSTOMER)).isEqualTo(24);
    }
}
