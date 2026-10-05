import { describe, it, expect, beforeEach, vi } from "vitest";

/**
 * The dashboard used to sign the admin out on any 401, even when a perfectly good refresh token was
 * still valid. These tests pin the silent-refresh-and-retry behaviour so it doesn't regress.
 *
 * F-05: the refresh token is an HttpOnly cookie the browser sends on its own (so a refresh carries
 * credentials + the CSRF header and no token in its body); the access token lives only in memory.
 *
 * We drive `request()` indirectly via `api.dashboardRaw()` (any endpoint would do) because `request`
 * itself is module-private.
 */

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

const authOf = (call) => new Headers(call[1].headers).get("Authorization");

describe("api.js — silent refresh on 401", () => {
  let api;
  let getAccessToken;
  let clearTokens;

  beforeEach(async () => {
    vi.resetModules();
    // Fresh import so each test gets a fresh `refreshInFlight` module-scope var.
    let setTokens;
    ({ api, getAccessToken, setTokens, clearTokens } = await import("../api.js"));
    setTokens({ accessToken: "expired-access-token" });
  });

  it("swaps the expired access token for a new one and retries the original request", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Authentication required" }),
      jsonRes(200, { data: { accessToken: "new-access" } }),
      jsonRes(200, { data: { totals: { customers: 6 } } })
    ]);

    const result = await api.dashboardRaw();

    expect(result).toEqual({ totals: { customers: 6 } });
    expect(getAccessToken()).toBe("new-access");
    expect(globalThis.fetch).toHaveBeenCalledTimes(3);
    // The refresh sends the cookie (credentials) and the CSRF header, and no token in its body.
    const refreshCall = globalThis.fetch.mock.calls[1];
    expect(String(refreshCall[0])).toContain("/auth/refresh");
    expect(refreshCall[1].credentials).toBe("include");
    expect(new Headers(refreshCall[1].headers).get("X-Requested-With")).toBe("aiwa-admin");
    expect(refreshCall[1].body).toBe("{}");
    // The retry must use the NEW token, not the expired one.
    expect(authOf(globalThis.fetch.mock.calls[2])).toBe("Bearer new-access");
  });

  it("signing out while a refresh is in flight does not sign back in (DR-003)", async () => {
    let releaseRefresh;
    const spy = vi.spyOn(globalThis, "fetch");
    spy.mockImplementationOnce(async () => jsonRes(401, { error: "Unauthorized" }));
    spy.mockImplementationOnce(() => new Promise((resolve) => {
      releaseRefresh = () => resolve(jsonRes(200, { data: { accessToken: "new-access" } }));
    }));

    const pending = api.dashboardRaw();
    await vi.waitFor(() => expect(releaseRefresh).toBeTypeOf("function"));
    clearTokens();          // the admin signs out
    releaseRefresh();       // ...and only then the refresh answers

    await expect(pending).rejects.toMatchObject({ status: 401 });
    expect(getAccessToken()).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_session")).toBeNull();
    expect(globalThis.fetch).toHaveBeenCalledTimes(2); // no retry under the old session
  });

  it("gives up cleanly when the refresh cookie is also dead — throws the original 401", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Authentication required" }),
      jsonRes(401, { error: "Unauthorized", message: "Invalid refresh token" })
    ]);

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 401 });
    // Only two calls — no infinite retry loop. The original + one refresh attempt.
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  // SA-14: only a refresh the server rejects ends the session.
  it.each([
    ["a 503 answer", () => jsonRes(503, { message: "down" })],
    ["a proxy error page", () => ({ ok: false, status: 502, text: async () => "<html>Bad gateway</html>" })],
    ["a network failure", () => { throw new TypeError("Failed to fetch"); }]
  ])("keeps the session and answers a temporary failure when the refresh gets %s", async (_name, refreshAnswer) => {
    const spy = vi.spyOn(globalThis, "fetch");
    spy.mockImplementationOnce(async () => jsonRes(401, { message: "expired" }));
    spy.mockImplementationOnce(async () => refreshAnswer());

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 503, transient: true });
    expect(getAccessToken()).toBe("expired-access-token");
    expect(window.localStorage.getItem("aiwa_admin_session")).not.toBeNull();
  });

  it("does not attempt to refresh when /auth/login itself 401s (that IS the login screen)", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized", message: "Invalid credentials" })
    ]);

    await expect(
      api.login({ email: "bad@x.com", password: "wrong" })
    ).rejects.toMatchObject({ status: 401 });

    // A refresh attempt here would be nonsensical — no session exists yet.
    // Only the login call should have been made, with credentials so the cookie can be set.
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    expect(globalThis.fetch.mock.calls[0][0]).toContain("/auth/login");
    expect(globalThis.fetch.mock.calls[0][1].credentials).toBe("include");
  });

  it("does not attempt to refresh when /auth/refresh itself 401s (would be an infinite loop)", async () => {
    queueFetch([
      jsonRes(401, { error: "Unauthorized" }),
      jsonRes(401, { error: "Unauthorized" })
    ]);

    await expect(api.dashboardRaw()).rejects.toBeDefined();
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("does not fire the refresh call at all when there is no session", async () => {
    clearTokens();
    queueFetch([
      jsonRes(401, { error: "Unauthorized" })
    ]);

    await expect(api.dashboardRaw()).rejects.toMatchObject({ status: 401 });
    // Only the original request: no pointless POST /auth/refresh without a session.
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
  });

  it("restores the session after a reload: no access token in memory, the hint says a session exists", async () => {
    vi.resetModules();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    const fresh = await import("../api.js");
    expect(fresh.getAccessToken()).toBeNull();
    expect(fresh.hasSession()).toBe(true);
    queueFetch([
      jsonRes(401, { error: "Unauthorized" }),
      jsonRes(200, { data: { accessToken: "restored" } }),
      jsonRes(200, { data: { id: 7 } })
    ]);

    await expect(fresh.api.me()).resolves.toMatchObject({ id: 7 });
    expect(fresh.getAccessToken()).toBe("restored");
    expect(authOf(globalThis.fetch.mock.calls[2])).toBe("Bearer restored");
  });

  it("shares one refresh call across concurrent 401s instead of firing N of them", async () => {
    // Three widgets on a page fire together and all 401. They must share
    // a single POST /auth/refresh, not each fire their own.
    const responses = [
      jsonRes(401, {}),                                           // widget A initial
      jsonRes(401, {}),                                           // widget B initial
      jsonRes(401, {}),                                           // widget C initial
      jsonRes(200, { data: { accessToken: "shared-new" } }),      // single refresh
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
    expect(getAccessToken()).toBe("expired-access-token");
  });

  it("takes turns with other tabs through the Web Locks API when it exists", async () => {
    const request = vi.fn((_name, callback) => callback());
    vi.stubGlobal("navigator", { ...globalThis.navigator, locks: { request } });
    try {
      queueFetch([
        jsonRes(401, {}),
        jsonRes(200, { data: { accessToken: "locked-new" } }),
        jsonRes(200, { data: { ok: true } })
      ]);
      await api.dashboardRaw();
      expect(request).toHaveBeenCalledWith("aiwa-admin-refresh", expect.any(Function));
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
