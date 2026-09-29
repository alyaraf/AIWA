import { describe, it, expect, beforeEach, vi } from "vitest";

/**
 * Normalizers are the shim between the backend's raw JSON and what the UI
 * actually renders. A silent regression here means broken table rows with no
 * error thrown — just wrong data. Pin the ones that carry real business
 * logic (not just id-passthrough).
 *
 * We hit normalizers indirectly via the api functions that use them
 * (api.flags, api.bookings) with a mocked fetch, since the normalizers
 * themselves are module-private.
 */

function jsonRes(bodyObj) {
  return { ok: true, status: 200, text: async () => JSON.stringify(bodyObj) };
}

describe("api.js — normalizeFlag", () => {
  let api;

  beforeEach(async () => {
    vi.resetModules();
    ({ api } = await import("../api.js"));
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
  });

  it("uses targetUserId directly when the complaint is against a user", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 1, subject: "Rude",
          targetUserId: 42, targetProviderOwnerUserId: null,
          targetName: "Some Customer", complainantName: "Reporter",
          status: "OPEN", createdAt: "2026-01-01T10:00:00", flagged: true
        }]
      }
    }));

    const flags = await api.flags();
    expect(flags[0].targetUserId).toBe(42);
  });

  it("falls back to targetProviderOwnerUserId when the complaint is against a provider", async () => {
    // This was the fix that made "Send warning" work for provider flags.
    // Backend puts the shop owner's userId in targetProviderOwnerUserId when
    // the target is a provider (targetUser stays null then). The frontend
    // uses whichever is present so the warn button doesn't just disable.
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 2, subject: "Provider issue",
          targetUserId: null, targetProviderOwnerUserId: 99,
          targetName: "Yousef Beauty", complainantName: "Karim",
          status: "OPEN", createdAt: "2026-01-01T10:00:00", flagged: true
        }]
      }
    }));

    const flags = await api.flags();
    expect(flags[0].targetUserId).toBe(99);
  });

  it("leaves targetUserId null when neither field is present (nothing to warn)", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 3, subject: "Orphan complaint",
          targetUserId: null, targetProviderOwnerUserId: null,
          targetName: "Unknown", complainantName: "Reporter",
          status: "OPEN", createdAt: "2026-01-01T10:00:00", flagged: true
        }]
      }
    }));

    const flags = await api.flags();
    expect(flags[0].targetUserId).toBeNull();
  });
});

describe("api.js — normalizeBooking", () => {
  let api;

  beforeEach(async () => {
    vi.resetModules();
    ({ api } = await import("../api.js"));
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
  });

  it("carries travelFee through so the receipt breakdown line can render", async () => {
    // Home-service travel fee (option A). null means "no fee" (line hidden),
    // a positive number means "show service + travel = total breakdown".
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 100, status: "PENDING", paymentStatus: "CASH_PENDING",
          bookingDate: "2026-09-21", startTime: "10:00:00",
          totalPrice: 330.0, travelFee: 150.0, homeService: true,
          customer: { fullName: "Nour" }, provider: { businessName: "Layla" },
          service: { name: "Gel Manicure" }
        }]
      }
    }));

    const bookings = await api.bookings();
    expect(bookings[0].travelFee).toBe(150.0);
    expect(bookings[0].amount).toBe(330.0);
    expect(bookings[0].homeService).toBe(true);
  });

  it("leaves travelFee null when the booking has none (non-home or provider-covers)", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 101, status: "PENDING", paymentStatus: "CASH_PENDING",
          bookingDate: "2026-09-21", startTime: "10:00:00",
          totalPrice: 180.0, travelFee: null, homeService: false,
          customer: { fullName: "Nour" }, provider: { businessName: "Layla" },
          service: { name: "Gel Manicure" }
        }]
      }
    }));

    const bookings = await api.bookings();
    expect(bookings[0].travelFee).toBeNull();
    expect(bookings[0].homeService).toBe(false);
  });

  it("marks a booking with paymentStatus DISPUTED as dispute:true", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 102, status: "COMPLETED", paymentStatus: "DISPUTED",
          bookingDate: "2026-09-21", startTime: "10:00:00", totalPrice: 200,
          customer: { fullName: "Nour" }, provider: { businessName: "L" },
          service: { name: "S" }
        }]
      }
    }));

    const [b] = await api.bookings();
    expect(b.dispute).toBe(true);
  });

  it("prefixes the id with BK- for the display reference when the id is numeric", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonRes({
      data: {
        content: [{
          id: 555, status: "PENDING", paymentStatus: "CASH_PENDING",
          bookingDate: "2026-09-21", startTime: "10:00:00", totalPrice: 100,
          customer: { fullName: "N" }, provider: { businessName: "L" },
          service: { name: "S" }
        }]
      }
    }));

    const [b] = await api.bookings();
    expect(b.ref).toBe("BK-555");
  });
});
