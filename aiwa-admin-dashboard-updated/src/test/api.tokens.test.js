import { describe, it, expect, beforeEach, vi } from "vitest";
import { getAccessToken, setTokens, clearTokens } from "../api.js";

/**
 * Token storage is small but load-bearing — it's what the whole authenticated
 * session sits on. A silent regression here (e.g. localStorage key rename)
 * signs everyone out on their next reload.
 */

describe("api.js — token helpers", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("returns null when no access token is stored", () => {
    expect(getAccessToken()).toBeNull();
  });

  it("round-trips an accessToken via setTokens → getAccessToken", () => {
    setTokens({ accessToken: "abc.def.ghi", refreshToken: "xyz" });
    expect(getAccessToken()).toBe("abc.def.ghi");
  });

  it("does not overwrite existing tokens with undefined fields (partial updates are safe)", () => {
    setTokens({ accessToken: "first-access", refreshToken: "first-refresh" });
    // A partial payload (e.g. from an endpoint that only refreshes access)
    // must not blank out the refresh token.
    setTokens({ accessToken: "second-access" });
    expect(getAccessToken()).toBe("second-access");
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBe("first-refresh");
  });

  it("clearTokens removes both keys", () => {
    setTokens({ accessToken: "a", refreshToken: "b" });
    clearTokens();
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBeNull();
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBeNull();
  });

  it("stores tokens under the aiwa_admin_* keys so a stray localStorage inspector can find them", () => {
    // Pinning the exact key names — renaming them silently signs everyone out
    // on their next reload with no upgrade path.
    setTokens({ accessToken: "a1", refreshToken: "r1" });
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBe("a1");
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBe("r1");
  });
});
