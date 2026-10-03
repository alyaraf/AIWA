import { describe, it, expect, beforeEach, vi } from "vitest";

/**
 * CR-18 (admin) follow-up: the cross-tab storage listener must tell another
 * tab's REFRESH (new tokens, same session) from its SIGN-OUT (tokens removed) or
 * a different user signing in. Only the last two end this tab's session; a
 * refresh used to bump the session generation too, so a request in flight on
 * an expired token was thrown unretried and App's onAuthExpired then wiped the
 * other tab's fresh tokens (both tabs signed out).
 */

const TOKEN = "aiwa_admin_access_token";
const REFRESH = "aiwa_admin_refresh_token";

function res(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

const authOf = (call) => new Headers(call[1].headers).get("Authorization");
const paths = () => globalThis.fetch.mock.calls.map(([u]) => String(u).replace("http://api.test/api", ""));

// What the other tab does and the browser tells this one about.
function otherTabWrites(key, newValue) {
  const oldValue = window.localStorage.getItem(key);
  if (newValue === null) window.localStorage.removeItem(key); else window.localStorage.setItem(key, newValue);
  window.dispatchEvent(new StorageEvent("storage", { key, oldValue, newValue }));
}

// A JWT-shaped token for `sub` (the api only reads the subject claim).
const jwt = (sub) => `h.${btoa(JSON.stringify({ sub })).replace(/=+$/, "")}.s`;

describe("api.js — another tab's token writes (CR-18 follow-up)", () => {
  let api;
  let removeSpy;

  beforeEach(async () => {
    vi.resetModules();
    ({ api } = await import("../api.js"));
    window.localStorage.setItem(TOKEN, "expired-access");
    window.localStorage.setItem(REFRESH, "refresh-1");
    removeSpy = vi.spyOn(Storage.prototype, "removeItem");
  });

  it("retries with the stored token when another tab refreshed while the request was in flight", async () => {
    let answer401;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() => new Promise((resolve) => { answer401 = resolve; }))
      .mockImplementationOnce(async () => res(200, { data: { totals: { customers: 6 } } }));

    const pending = api.dashboardRaw();
    await vi.waitFor(() => expect(answer401).toBeTypeOf("function"));

    otherTabWrites(TOKEN, "tab-b-access");
    otherTabWrites(REFRESH, "refresh-2");
    answer401(res(401, { message: "expired" }));

    expect(await pending).toEqual({ totals: { customers: 6 } });
    expect(authOf(globalThis.fetch.mock.calls[1])).toBe("Bearer tab-b-access");
    expect(paths()).not.toContain("/auth/refresh");
    expect(removeSpy).not.toHaveBeenCalled();
    expect(window.localStorage.getItem(TOKEN)).toBe("tab-b-access");
    expect(window.localStorage.getItem(REFRESH)).toBe("refresh-2");
  });

  it("keeps the other tab's tokens when this tab's own refresh loses to the other tab's rotation", async () => {
    let finishRefresh;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, { message: "expired" }))
      .mockImplementationOnce(() => new Promise((resolve) => { finishRefresh = resolve; }))
      .mockImplementationOnce(async () => res(200, { data: { ok: true } }));

    const pending = api.dashboardRaw();
    await vi.waitFor(() => expect(finishRefresh).toBeTypeOf("function"));

    // The other tab rotated the refresh token first, so ours is rejected.
    otherTabWrites(TOKEN, "tab-b-access");
    otherTabWrites(REFRESH, "refresh-2");
    finishRefresh(res(401, { message: "refresh token reused" }));

    expect(await pending).toEqual({ ok: true });
    expect(authOf(globalThis.fetch.mock.calls[2])).toBe("Bearer tab-b-access");
    expect(removeSpy).not.toHaveBeenCalled();
    expect(window.localStorage.getItem(TOKEN)).toBe("tab-b-access");
  });

  it("does not retry or refresh when another tab signed out while the request was in flight", async () => {
    let answer401;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() => new Promise((resolve) => { answer401 = resolve; }));

    const pending = api.dashboardRaw().catch((e) => e);
    await vi.waitFor(() => expect(answer401).toBeTypeOf("function"));

    otherTabWrites(TOKEN, null);
    otherTabWrites(REFRESH, null);
    answer401(res(401, { message: "expired" }));

    expect((await pending).status).toBe(401);
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
  });

  it("drops an in-flight refresh when another tab signs in as a different user", async () => {
    window.localStorage.setItem(TOKEN, jwt("admin-1"));
    let finishRefresh;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, { message: "expired" }))
      .mockImplementationOnce(() => new Promise((resolve) => { finishRefresh = resolve; }));

    const pending = api.dashboardRaw().catch((e) => e);
    await vi.waitFor(() => expect(finishRefresh).toBeTypeOf("function"));

    otherTabWrites(TOKEN, jwt("admin-2"));
    otherTabWrites(REFRESH, "admin-2-refresh");
    finishRefresh(res(200, { data: { accessToken: jwt("admin-1"), refreshToken: "admin-1-refresh" } }));
    await pending;

    expect(window.localStorage.getItem(TOKEN)).toBe(jwt("admin-2"));
    expect(window.localStorage.getItem(REFRESH)).toBe("admin-2-refresh");
  });
});
