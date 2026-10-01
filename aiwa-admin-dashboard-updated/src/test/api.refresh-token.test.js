import { describe, it, expect, beforeEach, vi } from "vitest";

/**
 * The dashboard used to sign the admin out on any 401, even when a perfectly
 * good 7-day refresh token was sitting in localStorage. These tests pin the
 * silent-refresh-and-retry behaviour so it doesn't regress the next time
 * anyone touches api.js.
 *
 * We drive `request()` indirectly via `api.dashboardRaw()` (any endpoint
 * would do) because `request` itself is module-private.
 */

const API_BASE = "http://api.test/api";

// A helper that queues fetch responses in order — first call returns the
// first response, second call returns the second, etc.
function queueFetch(responses) {
  const spy = vi.spyOn(globalThis, "fetch");
  responses.forEach((r) => spy.mockImplementationOnce(async () => r));
  return spy;
}

function jsonRes(status, bodyObj) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(bodyObj)
  };
}

describe("api.js — silent refresh on 401", () => {
  let api;

  beforeEach(async () => {
    vi.resetModules();
    // Fresh import so each test gets a fresh `refreshInFlight` module-scope var.
    ({ api } = await import("../api.js"));
    window.localStorage.setItem("aiwa_admin_access_token", "expired-access-token");
    window.localStorage.setItem("aiwa_admin_refresh_token", "good-refresh-token");
  });

  it("swaps the expired access token for a new one and retries the original request", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Authentication required" }),
      jsonRes(200, { data: { accessToken: "new-access", refreshToken: "new-refresh" } }),
      jsonRes(200, { data: { totals: { customers: 6 } } })
    ]);

    const result = await api.dashboardRaw();

    expect(result).toEqual({ totals: { customers: 6 } });
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBe("new-access");
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBe("new-refresh");
    expect(globalThis.fetch).toHaveBeenCalledTimes(3);
    // The retry must use the NEW token, not the expired one.
    const retryHeaders = globalThis.fetch.mock.calls[2][1].headers;
    const auth = typeof retryHeaders.get === "function"
      ? retryHeaders.get("Authorization")
      : retryHeaders.Authorization;
    expect(auth).toBe("Bearer new-access");
  });

  it("signing out while a refresh is in flight does not sign back in (DR-003)", async () => {
    const { clearTokens } = await import("../api.js");
    let releaseRefresh;
    const spy = vi.spyOn(globalThis, "fetch");
    spy.mockImplementationOnce(async () => jsonRes(401, { error: "Unauthorized" }));
    spy.mockImplementationOnce(() => new Promise((resolve) => {
      releaseRefresh = () => resolve(jsonRes(200, { data: { accessToken: "new-access", refreshToken: "new-refresh" } }));
    }));

    const pending = api.dashboardRaw();
    await vi.waitFor(() => expect(releaseRefresh).toBeTypeOf("function"));
    clearTokens();          // the admin signs out
    releaseRefresh();       // ...and only then the refresh answers

    await expect(pending).rejects.toMatchObject({ status: 401 });
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBeNull();
    expect(globalThis.fetch).toHaveBeenCalledTimes(2); // no retry under the old session
  });

  it("gives up cleanly when the refresh token is also dead — throws the original 401", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Authentication required" }),
      jsonRes(401, { error: "Unauthorized", message: "Invalid refresh token" })
    ]);

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 401 });
    // Only two calls — no infinite retry loop. The original + one refresh attempt.
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("does not attempt to refresh when /auth/login itself 401s (that IS the login screen)", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Invalid credentials" })
    ]);

    await expect(
      api.login({ email: "bad@x.com", password: "wrong" })
    ).rejects.toMatchObject({ status: 401 });

    // A refresh attempt here would be nonsensical — no session exists yet.
    // Only the login call should have been made.
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    expect(globalThis.fetch.mock.calls[0][0]).toContain("/auth/login");
  });

  it("does not attempt to refresh when /auth/refresh itself 401s (would be an infinite loop)", async () => {
    // Directly-triggered refresh is not a code path we call, but we can
    // simulate the guarded behaviour by making the initial request 401 and
    // then the refresh itself 401 — the second 401 must NOT itself trigger
    // another refresh. Covered by "gives up cleanly" above too, this test
    // just pins fetch-count to exactly 2, no third call slipping through.
    queueFetch([
      jsonRes(401, { error: "Unauthorized" }),
      jsonRes(401, { error: "Unauthorized" })
    ]);

    await expect(api.dashboardRaw()).rejects.toBeDefined();
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("does not fire the refresh call at all when no refresh token is stored", async () => {
    window.localStorage.removeItem("aiwa_admin_refresh_token");
    queueFetch([
      jsonRes(401, { error: "Unauthorized" })
    ]);

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 401 });
    // Only the original request. No pointless POST /auth/refresh with a
    // nonexistent token — that would just error the same way and waste a
    // round trip.
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
  });

  it("shares one refresh call across concurrent 401s instead of firing N of them", async () => {
    // Three widgets on a page fire together and all 401. They must share
    // a single POST /auth/refresh, not each fire their own.
    const responses = [
      jsonRes(401, {}),                                                            // widget A initial
      jsonRes(401, {}),                                                            // widget B initial
      jsonRes(401, {}),                                                            // widget C initial
      jsonRes(200, { data: { accessToken: "shared-new", refreshToken: "shared-r" } }), // single refresh
      jsonRes(200, { data: { widget: "A" } }),
      jsonRes(200, { data: { widget: "B" } }),
      jsonRes(200, { data: { widget: "C" } })
    ];
    queueFetch(responses);

    const [a, b, c] = await Promise.all([
      api.dashboardRaw(),
      api.dashboardRaw(),
      api.dashboardRaw()
    ]);

    expect(a).toEqual({ widget: "A" });
    expect(b).toEqual({ widget: "B" });
    expect(c).toEqual({ widget: "C" });

    // 3 original + 1 refresh + 3 retries = 7. NOT 3 + 3 + 3 = 9.
    expect(globalThis.fetch).toHaveBeenCalledTimes(7);
    const refreshCalls = globalThis.fetch.mock.calls.filter(
      ([url]) => String(url).endsWith("/auth/refresh")
    );
    expect(refreshCalls).toHaveLength(1);
  });

  it("passes non-401 errors straight through without touching refresh", async () => {
    queueFetch([
      jsonRes(500, { error: "Internal Server Error", message: "Something went wrong" })
    ]);

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 500 });
    // No refresh attempt for a 500 — refresh is only for auth failures.
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    // Token stays untouched.
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBe("expired-access-token");
  });
});
