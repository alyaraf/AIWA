package com.aiwa.enums;

public enum LedgerEntryStatus {
    DUE,
    SETTLED,
    OVERDUE,
    /** The booking turned out unpaid, voided or a no-show after the entry was recorded (R2-08). */
    VOID
}
