import { describe, it, expect, beforeEach } from "vitest";
import { getAccessToken, hasSession, setTokens, clearTokens } from "../api.js";

/**
 * F-05: nothing secret is stored where script can read it after the page is gone. The access token is
 * in memory only; the refresh token is an HttpOnly cookie. localStorage holds just a non-secret
 * "a session exists" hint. A regression here (a token back in localStorage) is the finding coming back.
 */

describe("api.js — session helpers", () => {
  beforeEach(() => {
    clearTokens();
    window.localStorage.clear();
  });

  it("returns null and no session when nobody is signed in", () => {
    expect(getAccessToken()).toBeNull();
    expect(hasSession()).toBe(false);
  });

  it("round-trips an accessToken via setTokens → getAccessToken", () => {
    setTokens({ accessToken: "abc.def.ghi" });
    expect(getAccessToken()).toBe("abc.def.ghi");
    expect(hasSession()).toBe(true);
  });

  it("does not overwrite the access token with an undefined field", () => {
    setTokens({ accessToken: "first-access" });
    setTokens({});
    expect(getAccessToken()).toBe("first-access");
  });

  it("never writes a token to localStorage, even when the response still carries a refresh token", () => {
    setTokens({ accessToken: "secret-access", refreshToken: "secret-refresh" });
    const stored = Object.keys(window.localStorage).map((key) => `${key}=${window.localStorage.getItem(key)}`).join("\n");
    expect(stored).not.toContain("secret-access");
    expect(stored).not.toContain("secret-refresh");
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_session")).not.toBeNull(); // the hint only
  });

  it("clearTokens removes the token and the hint", () => {
    setTokens({ accessToken: "a" });
    clearTokens();
    expect(getAccessToken()).toBeNull();
    expect(hasSession()).toBe(false);
    expect(window.localStorage.getItem("aiwa_admin_session")).toBeNull();
  });

  it("each sign-in gets a new hint, so other tabs notice a different session", () => {
    setTokens({ accessToken: "a" });
    const first = window.localStorage.getItem("aiwa_admin_session");
    setTokens({ accessToken: "b" });
    expect(window.localStorage.getItem("aiwa_admin_session")).not.toBe(first);
  });

  it("removes tokens an older build left in localStorage when the module loads", async () => {
    window.localStorage.setItem("aiwa_admin_access_token", "old-a");
    window.localStorage.setItem("aiwa_admin_refresh_token", "old-r");
    const { vi } = await import("vitest");
    vi.resetModules();
    await import("../api.js");
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBeNull();
  });
});
