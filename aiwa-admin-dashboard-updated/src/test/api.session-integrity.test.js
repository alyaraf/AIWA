import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/**
 * AD-04 / P-03 / P-04 / AD-13 / AD-09: session ordering and list completeness in the API adapter.
 */

const SESSION = "aiwa_admin_session";
const ACTIVITY = "aiwa_admin_last_activity";
const MINUTE = 60_000;

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

describe("api.js - session integrity", () => {
  let mod;

  beforeEach(async () => {
    vi.resetModules();
    window.localStorage.clear();
    mod = await import("../api.js");
  });
  afterEach(() => vi.restoreAllMocks());

  it("P-04: a successful answer that arrives after sign-out is discarded, not returned", async () => {
    mod.setTokens({ accessToken: "admin-a" });
    let answer;
    vi.spyOn(globalThis, "fetch").mockImplementationOnce(() => new Promise((resolve) => { answer = resolve; }));

    const pending = mod.api.dashboardRaw().catch((error) => error);
    await vi.waitFor(() => expect(answer).toBeTypeOf("function"));
    mod.clearTokens(); // admin A signs out, admin B is about to sign in
    answer(json(200, { success: true, data: { customers: 99, pii: "admin A only" } }));

    const result = await pending;
    expect(result).toBeInstanceOf(Error);
    expect(result.stale).toBe(true);
    expect(result.code).toBe("SESSION_CHANGED");
  });

  it("P-04: a late answer after a new sign-in is discarded too", async () => {
    mod.setTokens({ accessToken: "admin-a" });
    let answer;
    vi.spyOn(globalThis, "fetch").mockImplementationOnce(() => new Promise((resolve) => { answer = resolve; }));
    const pending = mod.api.dashboardRaw().catch((error) => error);
    await vi.waitFor(() => expect(answer).toBeTypeOf("function"));

    mod.setTokens({ accessToken: "admin-b" });
    answer(json(200, { success: true, data: { secret: "for A" } }));

    expect((await pending).stale).toBe(true);
  });

  it("P-03: a sign-in waits for the sign-out that is still in flight", async () => {
    mod.setTokens({ accessToken: "admin-a" });
    const order = [];
    let finishLogout;
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      const path = new URL(url).pathname;
      order.push(`start ${path}`);
      if (path.endsWith("/auth/logout")) {
        return new Promise((resolve) => { finishLogout = () => { order.push("end logout"); resolve(json(200, {})); }; });
      }
      return Promise.resolve(json(200, { success: true, data: { accessToken: "b" } }));
    });

    const loggedOut = mod.api.logout();
    const loggingIn = mod.api.login({ identifier: "b@example.test", password: "x" });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(order).toEqual(["start /api/auth/logout"]); // login has not been sent yet

    finishLogout();
    await loggedOut;
    await loggingIn;
    expect(order).toEqual(["start /api/auth/logout", "end logout", "start /api/auth/login"]);
  });

  it("AD-04: a document or export download ends an idle session instead of using it", async () => {
    mod.setTokens({ accessToken: "old" });
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 45 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const ended = vi.fn();
    mod.onSessionEnded(ended);

    await expect(mod.api.verificationDocUrl("/private/doc.png")).rejects.toMatchObject({ status: 401, sessionEnded: true });
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(ended).toHaveBeenCalledWith("idle");
    expect(window.localStorage.getItem(SESSION)).toBeNull();

    mod.setTokens({ accessToken: "old" });
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 45 * MINUTE));
    await expect(mod.api.exportAudit("")).rejects.toMatchObject({ status: 401, sessionEnded: true });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("AD-04: the idle check can run without any request and tells the App once", () => {
    mod.setTokens({ accessToken: "a" });
    const ended = vi.fn();
    mod.onSessionEnded(ended);
    expect(mod.enforceIdleLimit()).toBe(false);
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 45 * MINUTE));
    expect(mod.enforceIdleLimit()).toBe(true);
    expect(mod.enforceIdleLimit()).toBe(false); // already ended
    expect(ended).toHaveBeenCalledTimes(1);
    expect(mod.getAccessToken()).toBeNull();
  });

  it("AD-04: a refresh the server rejects tells every listener the session ended", async () => {
    mod.setTokens({ accessToken: "a" });
    vi.spyOn(globalThis, "fetch").mockImplementation(async () => json(401, { message: "expired" }));
    const ended = vi.fn();
    mod.onSessionEnded(ended);

    await expect(mod.api.dashboardRaw()).rejects.toMatchObject({ status: 401 });
    expect(ended).toHaveBeenCalledWith("expired");
  });

  it("signing in works even when a stale idle record from an old session is still in storage", async () => {
    window.localStorage.setItem(SESSION, "old-hint");
    window.localStorage.setItem(ACTIVITY, String(Date.now() - 90 * MINUTE));
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      json(200, { success: true, data: { accessToken: "new" } }));
    const ended = vi.fn();
    mod.onSessionEnded(ended);

    await expect(mod.api.login({ identifier: "a@b.test", password: "x" })).resolves.toMatchObject({ accessToken: "new" });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(ended).not.toHaveBeenCalled(); // clearing a dead record is not a "session ended" event for the App
  });

  it("a failed sign-in (401 on /auth/login) does not announce a session end", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () => json(401, { message: "bad credentials" }));
    const ended = vi.fn();
    mod.onSessionEnded(ended);
    await expect(mod.api.login({ identifier: "x@y.test", password: "nope" })).rejects.toMatchObject({ status: 401 });
    expect(ended).not.toHaveBeenCalled();
  });

  it("AD-13: a list that hits the page cap says it was truncated, and the rows still come back", async () => {
    mod.setTokens({ accessToken: "a" });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
      const u = new URL(url);
      const page = Number(u.searchParams.get("page"));
      const size = Number(u.searchParams.get("size"));
      const content = Array.from({ length: size }, (_, i) => ({ id: page * size + i + 1, status: "OPEN", subject: "x" }));
      return json(200, { success: true, data: { content, totalPages: 51, totalElements: 10_200, number: page } });
    });

    const rows = await mod.api.complaints();

    expect(rows).toHaveLength(10_000);
    expect(mod.isTruncated(rows)).toBe(true);
    expect(rows.serverTotal).toBe(10_200);
    expect(Object.keys(rows)).not.toContain("truncated"); // not enumerable: spreading/mapping is unaffected
  });

  it("AD-13: a list that fits is not marked", async () => {
    mod.setTokens({ accessToken: "a" });
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      json(200, { success: true, data: { content: [{ id: 1, status: "OPEN" }], totalPages: 1, totalElements: 1, number: 0 } }));
    expect(mod.isTruncated(await mod.api.complaints())).toBe(false);
  });

  it("AD-09: the real review DTO (hidden boolean, no status) keeps its visibility", async () => {
    mod.setTokens({ accessToken: "a" });
    vi.spyOn(globalThis, "fetch").mockImplementation(async () => json(200, { success: true, data: { content: [
      { id: 1, user: { fullName: "Mona" }, provider: { businessName: "Studio" }, rating: 2, comment: "meh", hidden: true },
      { id: 2, user: { fullName: "Omar" }, provider: { businessName: "Studio" }, rating: 5, comment: "great", hidden: false }
    ], totalPages: 1, number: 0 } }));
    const [hidden, visible] = await mod.api.reviews();
    expect(hidden).toMatchObject({ hidden: true, status: "HIDDEN" });
    expect(visible).toMatchObject({ hidden: false, status: "VISIBLE" });
  });
});
