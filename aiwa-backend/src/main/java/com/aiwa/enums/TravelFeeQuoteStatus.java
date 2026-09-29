package com.aiwa.enums;

/** State of a provider's per-booking travel-fee quote. */
public enum TravelFeeQuoteStatus {
    /** Quoted by the provider, waiting for the customer. */
    PENDING,
    ACCEPTED,
    DECLINED
}
