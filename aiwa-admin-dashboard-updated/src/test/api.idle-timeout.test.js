import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/**
 * S-04 (incremental): admin tokens still sit in localStorage, so an admin who walks away must be
 * signed out after the idle limit (30 minutes by default) instead of staying signed in for the
 * full refresh-token lifetime.
 */

const ACCESS = "aiwa_admin_access_token";
const REFRESH = "aiwa_admin_refresh_token";
const ACTIVITY = "aiwa_admin_last_activity";
const MINUTE = 60_000;

describe("api.js - idle sign-out", () => {
  let mod;

  beforeEach(async () => {
    vi.resetModules();
    mod = await import("../api.js");
  });

  afterEach(() => vi.restoreAllMocks());

  it("starts the idle clock when tokens are stored and clears it with them", () => {
    mod.setTokens({ accessToken: "a", refreshToken: "r" });
    expect(Number(window.localStorage.getItem(ACTIVITY))).toBeGreaterThan(0);
    mod.clearTokens();
    expect(window.localStorage.getItem(ACTIVITY)).toBeNull();
  });

  it("is not idle just after activity, and is idle after the limit", () => {
    mod.setTokens({ accessToken: "a", refreshToken: "r" });
    expect(mod.sessionIdleExpired(Date.now() + 29 * MINUTE)).toBe(false);
    expect(mod.sessionIdleExpired(Date.now() + 31 * MINUTE)).toBe(true);
  });

  it("treats a session with no activity record as fresh", () => {
    window.localStorage.setItem(ACCESS, "a");
    expect(mod.sessionIdleExpired()).toBe(false);
  });

  it("drops the tokens instead of sending them once the session has been idle too long", async () => {
    window.localStorage.setItem(ACCESS, "old-access");
    window.localStorage.setItem(REFRESH, "old-refresh");
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 45 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => ({
      ok: false, status: 401, text: async () => JSON.stringify({ message: "Unauthorized" })
    }));

    await expect(mod.api.me()).rejects.toMatchObject({ status: 401 });

    expect(window.localStorage.getItem(ACCESS)).toBeNull();
    expect(window.localStorage.getItem(REFRESH)).toBeNull();
    // No refresh attempt was made with the stale refresh token, and the stale bearer was not sent.
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(new Headers(fetchSpy.mock.calls[0][1].headers).get("Authorization")).toBeNull();
  });

  it("keeps an active session signed in", async () => {
    window.localStorage.setItem(ACCESS, "live-access");
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 5 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => ({
      ok: true, status: 200, text: async () => JSON.stringify({ data: { id: 1 } })
    }));

    await mod.api.me();

    expect(window.localStorage.getItem(ACCESS)).toBe("live-access");
    expect(new Headers(fetchSpy.mock.calls[0][1].headers).get("Authorization")).toBe("Bearer live-access");
  });
});
