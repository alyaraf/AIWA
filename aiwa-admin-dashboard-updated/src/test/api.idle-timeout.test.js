import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/**
 * S-04: an admin who walks away must be signed out after the idle limit (30 minutes by default)
 * instead of staying signed in for the full refresh-cookie lifetime.
 */

const SESSION = "aiwa_admin_session";
const ACTIVITY = "aiwa_admin_last_activity";
const MINUTE = 60_000;

describe("api.js - idle sign-out", () => {
  let mod;

  beforeEach(async () => {
    vi.resetModules();
    window.localStorage.clear();
    mod = await import("../api.js");
  });

  afterEach(() => vi.restoreAllMocks());

  it("starts the idle clock when a session starts and clears it with the session", () => {
    mod.setTokens({ accessToken: "a" });
    expect(Number(window.localStorage.getItem(ACTIVITY))).toBeGreaterThan(0);
    mod.clearTokens();
    expect(window.localStorage.getItem(ACTIVITY)).toBeNull();
  });

  it("is not idle just after activity, and is idle after the limit", () => {
    mod.setTokens({ accessToken: "a" });
    expect(mod.sessionIdleExpired(Date.now() + 29 * MINUTE)).toBe(false);
    expect(mod.sessionIdleExpired(Date.now() + 31 * MINUTE)).toBe(true);
  });

  it("treats a session with no activity record as fresh", () => {
    window.localStorage.setItem(SESSION, "hint");
    expect(mod.sessionIdleExpired()).toBe(false);
  });

  it("ends the session instead of using it once it has been idle too long", async () => {
    mod.setTokens({ accessToken: "old-access" });
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 45 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => ({
      ok: false, status: 401, text: async () => JSON.stringify({ message: "Unauthorized" })
    }));

    await expect(mod.api.me()).rejects.toMatchObject({ status: 401 });

    expect(mod.getAccessToken()).toBeNull();
    expect(window.localStorage.getItem(SESSION)).toBeNull();
    // AD-04: the session is ended first and the call is not made at all, with or without the stale bearer.
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("keeps an active session signed in", async () => {
    mod.setTokens({ accessToken: "live-access" });
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 5 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => ({
      ok: true, status: 200, text: async () => JSON.stringify({ data: { id: 1 } })
    }));

    await mod.api.me();

    expect(mod.getAccessToken()).toBe("live-access");
    expect(new Headers(fetchSpy.mock.calls[0][1].headers).get("Authorization")).toBe("Bearer live-access");
  });
});
