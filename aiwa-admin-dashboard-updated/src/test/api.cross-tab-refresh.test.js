import { describe, it, expect, beforeEach, vi } from "vitest";

/**
 * CR-18 (admin), reworked for F-05. Tabs share the refresh cookie but each holds its own in-memory
 * access token, so a refresh by another tab needs no adoption: this tab keeps its token or refreshes
 * through the cookie. What a tab must notice is another tab's SIGN-OUT or a NEW sign-in, both of which
 * change the non-secret session hint in localStorage. Then whatever this tab has in flight belongs to
 * the old session and must not write over the new one.
 */

const SESSION = "aiwa_admin_session";

function res(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

const authOf = (call) => new Headers(call[1].headers).get("Authorization");
const paths = () => globalThis.fetch.mock.calls.map(([u]) => String(u).replace("http://api.test/api", ""));

// What the other tab does and the browser tells this one about.
function otherTabWrites(newValue) {
  const oldValue = window.localStorage.getItem(SESSION);
  if (newValue === null) window.localStorage.removeItem(SESSION); else window.localStorage.setItem(SESSION, newValue);
  window.dispatchEvent(new StorageEvent("storage", { key: SESSION, oldValue, newValue }));
}

describe("api.js — another tab's session changes (CR-18 follow-up, F-05)", () => {
  let api;
  let mod;

  beforeEach(async () => {
    vi.resetModules();
    window.localStorage.clear();
    mod = await import("../api.js");
    ({ api } = mod);
    mod.setTokens({ accessToken: "expired-access" });
  });

  it("does not touch the session when another tab merely refreshed (the hint is unchanged)", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, { message: "expired" }))
      .mockImplementationOnce(async () => res(200, { data: { accessToken: "fresh" } }))
      .mockImplementationOnce(async () => res(200, { data: { totals: { customers: 6 } } }));

    expect(await api.dashboardRaw()).toEqual({ totals: { customers: 6 } });
    expect(authOf(globalThis.fetch.mock.calls[2])).toBe("Bearer fresh");
    expect(window.localStorage.getItem(SESSION)).not.toBeNull();
  });

  it("does not retry or refresh when another tab signed out while the request was in flight", async () => {
    let answer401;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() => new Promise((resolve) => { answer401 = resolve; }));

    const pending = api.dashboardRaw().catch((e) => e);
    await vi.waitFor(() => expect(answer401).toBeTypeOf("function"));

    otherTabWrites(null);
    answer401(res(401, { message: "expired" }));

    // P-04: the answer belongs to the session that ended, so it is discarded as stale (status 0), never reported
    // as a 401 that would end whichever session is current now.
    const failure = await pending;
    expect(failure.stale).toBe(true);
    expect(failure.status).toBe(0);
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    expect(mod.getAccessToken()).toBeNull();
  });

  it("drops an in-flight refresh when another tab signs in again", async () => {
    let finishRefresh;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, { message: "expired" }))
      .mockImplementationOnce(() => new Promise((resolve) => { finishRefresh = resolve; }));

    const pending = api.dashboardRaw().catch((e) => e);
    await vi.waitFor(() => expect(finishRefresh).toBeTypeOf("function"));

    otherTabWrites("another-session");
    finishRefresh(res(200, { data: { accessToken: "token-of-the-old-session" } }));
    await pending;

    expect(mod.getAccessToken()).toBeNull();   // not written over the new session
    expect(paths().filter((p) => p === "/auth/refresh")).toHaveLength(1);
  });

  it("drops its access token when another tab signs in, then gets one for the new session through the cookie", async () => {
    otherTabWrites("another-session");
    expect(mod.getAccessToken()).toBeNull();
    expect(mod.hasSession()).toBe(true);

    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, {}))
      .mockImplementationOnce(async () => res(200, { data: { accessToken: "new-session-access" } }))
      .mockImplementationOnce(async () => res(200, { data: { id: 2 } }));

    await expect(api.me()).resolves.toMatchObject({ id: 2 });
    expect(mod.getAccessToken()).toBe("new-session-access");
  });

  it("ignores storage events for other keys", () => {
    window.dispatchEvent(new StorageEvent("storage", { key: "something-else", newValue: "x" }));
    expect(mod.getAccessToken()).toBe("expired-access");
  });
});
