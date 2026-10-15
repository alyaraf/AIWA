import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/** A refused export (more rows than the server's cap) shows the server's reason, not only a status code. */
describe("api.js - refused exports", () => {
  let mod;

  beforeEach(async () => {
    vi.resetModules();
    window.localStorage.clear();
    mod = await import("../api.js");
    mod.setTokens({ accessToken: "A" });
  });
  afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });

  it("carries the server's message", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue({
      status: 400, ok: false,
      json: async () => ({ code: "admin.error.export_too_large", message: "This export has more than 10,000 bookings." }),
    });
    const error = await mod.api.exportBookingList("", "All").catch((e) => e);
    expect(error.status).toBe(400);
    expect(error.serverMessage).toBe("This export has more than 10,000 bookings.");
    expect(error.message).toBe("This export has more than 10,000 bookings.");
  });

  it("falls back to the status when the body is not JSON", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ status: 502, ok: false, json: async () => { throw new SyntaxError("x"); } });
    const error = await mod.api.exportBookingList("", "All").catch((e) => e);
    expect(error.serverMessage).toBeNull();
    expect(error.message).toBe("Export failed with status 502");
  });
});
