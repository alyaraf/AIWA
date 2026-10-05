import { describe, it, expect, afterEach } from "vitest";
import { navAllowed, canManageTarget, __setPermissionsForTest } from "../App.jsx";

/** S-05: the sidebar only offers screens the API will answer for this admin. */
describe("navAllowed", () => {
  afterEach(() => __setPermissionsForTest([]));

  it("offers the audit log to Super admin only", () => {
    __setPermissionsForTest(["FINANCE", "SUPPORT"]);
    expect(navAllowed("audit")).toBe(false);
    __setPermissionsForTest(["SUPER_ADMIN"]);
    expect(navAllowed("audit")).toBe(true);
  });

  it("offers settlements to Finance, bookings to Support or Finance", () => {
    __setPermissionsForTest(["SUPPORT"]);
    expect(navAllowed("settlements")).toBe(false);
    expect(navAllowed("bookings")).toBe(true);
    __setPermissionsForTest(["FINANCE"]);
    expect(navAllowed("settlements")).toBe(true);
    expect(navAllowed("bookings")).toBe(true);
  });

  it("offers every screen that holds personal data only to the capability the API requires (B-04 / AD-08)", () => {
    __setPermissionsForTest(["FINANCE"]);
    for (const id of ["safety", "verifications", "complaints", "flags", "reviews", "moderation", "chat-reports"]) {
      expect(navAllowed(id), id).toBe(false);
    }
    expect(navAllowed("users")).toBe(true);
    __setPermissionsForTest(["SUPPORT"]);
    for (const id of ["safety", "verifications", "complaints", "flags", "reviews", "moderation", "chat-reports", "users", "bookings"]) {
      expect(navAllowed(id), id).toBe(true);
    }
    __setPermissionsForTest(["SUPER_ADMIN"]);
    for (const item of ["safety", "reviews", "settlements", "audit", "users"]) expect(navAllowed(item), item).toBe(true);
  });

  it("an admin with no permission only keeps the screens without personal data", () => {
    __setPermissionsForTest([]);
    for (const id of ["safety", "complaints", "flags", "reviews", "users", "bookings", "settlements", "audit"]) {
      expect(navAllowed(id), id).toBe(false);
    }
    expect(navAllowed("dashboard")).toBe(true);
    expect(navAllowed("settings")).toBe(true);
  });

  it("another admin account can only be managed by a Super admin", () => {
    __setPermissionsForTest(["SUPPORT"]);
    expect(canManageTarget({ role: "CUSTOMER" })).toBe(true);
    expect(canManageTarget({ role: "ADMIN" })).toBe(false);
    __setPermissionsForTest(["SUPER_ADMIN"]);
    expect(canManageTarget({ role: "ADMIN" })).toBe(true);
  });
});
