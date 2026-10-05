import { describe, it, expect, afterEach } from "vitest";
import { navAllowed, __setPermissionsForTest } from "../App.jsx";

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

  it("hides all three from an admin with no permission and never hides other screens", () => {
    __setPermissionsForTest([]);
    expect(navAllowed("audit") || navAllowed("settlements") || navAllowed("bookings")).toBe(false);
    expect(navAllowed("dashboard")).toBe(true);
    expect(navAllowed("complaints")).toBe(true);
  });
});
